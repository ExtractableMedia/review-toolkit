#!/usr/bin/env node

/**
 * MCP Review Triage Server
 *
 * Provides interactive triage of review findings (from /doc-review,
 * /local-review, etc.) using MCP elicitation for per-item action menus.
 *
 * Partially addresses: https://github.com/anthropics/claude-code/issues/32724
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Finding {
  /** e.g. "F1" */
  id: string;
  /** Raw severity emoji + text, e.g. "🟡 Medium Priority" */
  severity: string;
  /** Finding title after the severity dash */
  title: string;
  /** Full body text (location, issue, suggestion, etc.) */
  body: string;
  /** Whether the finding is already resolved (✅/🚫/⏸️) */
  resolved: boolean;
  /** Line offset in the source file where the heading starts */
  headingLine: number;
  /** The raw heading line for file-update purposes */
  rawHeading: string;
}

type Action = "fix" | "fix_guided" | "accept" | "defer" | "ignore" | "skip";

interface Decision {
  finding: string;
  action: Action;
  guidance: string | null;
  severity: string;
  title: string;
}

// ---------------------------------------------------------------------------
// Finding parser
// ---------------------------------------------------------------------------

/**
 * Parses a review document (local-review.md, *-DOC-REVIEW.md) into findings.
 *
 * Supports the heading format produced by /local-review and /doc-review:
 *   ### F1 🟡 Medium Priority - Description
 *   ### F1 ~~🟡 Medium Priority - Description~~ ✅ Fixed
 */
function parseFindings(content: string): Finding[] {
  const lines = content.split("\n");
  const findings: Finding[] = [];

  // Match: ### F<n> <severity> <dash> <title>
  // Accepts hyphen (-), en dash (–), or em dash (—) as separator
  // Also handles resolved: ### F<n> ~~<severity> <dash> <title>~~ <status>
  const headingRe =
    /^###\s+(F\d+)\s+(?:~~)?([🔴🟠🟡🟢ℹ️]+\s+(?:Critical|High Priority|Medium Priority|Low Priority|Nice-to-Have|Observation)\s*)[-–—]\s*(.+?)(?:~~\s*[✅🚫⏸️].*)?$/u;

  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(headingRe);
    if (!match) continue;

    const [, id, severity, title] = match;
    const resolved = /~~.*~~/.test(lines[i]);

    // Collect body lines until the next heading or end of file
    const bodyLines: string[] = [];
    for (let j = i + 1; j < lines.length; j++) {
      if (/^###?\s/.test(lines[j])) break;
      bodyLines.push(lines[j]);
    }

    findings.push({
      id,
      severity: severity.trim(),
      title: title.trim(),
      body: bodyLines.join("\n").trim(),
      resolved,
      headingLine: i,
      rawHeading: lines[i],
    });
  }

  return findings;
}

// ---------------------------------------------------------------------------
// File updater
// ---------------------------------------------------------------------------

/**
 * Marks a finding in the source file with the given status.
 *
 * Transforms:
 *   ### F1 🟡 Medium Priority - Description
 * Into:
 *   ### F1 ~~🟡 Medium Priority - Description~~ ✅ Accepted
 */
function markFinding(
  content: string,
  finding: Finding,
  action: "accept" | "defer" | "ignore",
): string {
  const markers: Record<string, { icon: string; label: string }> = {
    accept: { icon: "✅", label: "Accepted" },
    defer: { icon: "⏸️", label: "Deferred" },
    ignore: { icon: "🚫", label: "Ignored" },
  };
  const { icon, label } = markers[action];
  const lines = content.split("\n");
  const line = lines[finding.headingLine];

  // Replace the heading with strikethrough + status marker
  const updatedLine = line.replace(
    /^(###\s+F\d+\s+)(.+)$/,
    `$1~~$2~~ ${icon} ${label}`,
  );
  lines[finding.headingLine] = updatedLine;

  // Insert a status line after the heading
  const statusLine = `**Status:** ${label}`;
  let insertIdx = finding.headingLine + 1;
  while (insertIdx < lines.length && lines[insertIdx].trim() === "") {
    insertIdx++;
  }
  lines.splice(insertIdx, 0, "", statusLine);

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

const mcpServer = new McpServer(
  {
    name: "mcp-review-triage",
    version: "0.1.0",
  },
  {
    capabilities: {
      // Server declares it will use elicitation
    },
  },
);

mcpServer.tool(
  "triage_findings",
  "Interactively triage review findings one at a time. " +
    "Reads a findings file (from /doc-review or /local-review), " +
    "presents each unresolved finding with an action menu via " +
    "elicitation, and returns structured results for Claude to act on.",
  {
    file_path: z
      .string()
      .describe(
        "Absolute path to the review findings file " +
          "(e.g. local-review.md or *-DOC-REVIEW.md)",
      ),
    severity_filter: z
      .array(z.enum(["critical", "high", "medium", "low"]))
      .optional()
      .describe(
        "Only show findings matching these severities. " +
          "Omit to show all unresolved findings.",
      ),
    update_file: z
      .boolean()
      .default(true)
      .describe(
        "Whether to update the source file with status markers " +
          "for accept/defer/ignore actions.",
      ),
  },
  async ({ file_path, severity_filter, update_file }) => {
    // Read and parse findings file
    const absPath = resolve(file_path);
    let content: string;
    try {
      content = readFileSync(absPath, "utf-8");
    } catch (err) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Error reading file: ${(err as Error).message}`,
          },
        ],
        isError: true,
      };
    }

    const allFindings = parseFindings(content);
    if (allFindings.length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: "No findings found in the file. Make sure the file uses " +
              "the expected heading format " +
              "(### F1 🟡 Medium Priority - Description).",
          },
        ],
      };
    }

    // Filter to unresolved, actionable findings
    const severityMap: Record<string, string> = {
      critical: "Critical",
      high: "High Priority",
      medium: "Medium Priority",
      low: "Low Priority",
    };

    let findings = allFindings.filter((f) => {
      if (f.resolved) return false;
      // Skip observations (ℹ️) — they don't need triage
      if (f.severity.includes("Observation")) return false;
      if (severity_filter && severity_filter.length > 0) {
        return severity_filter.some((s) =>
          f.severity.includes(severityMap[s] || s),
        );
      }
      return true;
    });

    if (findings.length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: `All ${allFindings.length} findings are either resolved ` +
              `or filtered out. Nothing to triage.`,
          },
        ],
      };
    }

    // Triage loop — present each finding via elicitation
    const decisions: Decision[] = [];
    let currentContent = content;
    let cancelled = false;

    for (let i = 0; i < findings.length && !cancelled; i++) {
      const finding = findings[i];
      const progress = `${i + 1} of ${findings.length}`;
      const header =
        `${finding.id} ${finding.severity} — ${finding.title}`;

      // Build a short summary for the initial message. Extract the
      // first meaningful line from the body (usually **File:** or
      // **Location:**) so the user has minimal context at a glance.
      const summaryLine = finding.body
        .split("\n")
        .find((l) => l.trim().length > 0) ?? "";

      // Action selection loop — re-presents after "View details"
      let decided = false;
      while (!decided) {
        const result = await mcpServer.server.elicitInput({
          mode: "form",
          message:
            `── Finding ${progress} ── ${header}. ${summaryLine}`,
          requestedSchema: {
            type: "object" as const,
            properties: {
              action: {
                type: "string",
                title: "Action",
                description: "What should happen with this finding?",
                oneOf: [
                  {
                    const: "details",
                    title: "View details — see full finding text",
                  },
                  {
                    const: "fix",
                    title: "Fix — dispatch agent to resolve",
                  },
                  {
                    const: "fix_guided",
                    title:
                      "Fix with guidance — add context for the agent",
                  },
                  {
                    const: "accept",
                    title: "Accept — mark as acceptable, no fix needed",
                  },
                  { const: "defer", title: "Defer — address later" },
                  { const: "ignore", title: "Ignore — won't fix" },
                  { const: "skip", title: "Skip — decide later" },
                ],
              },
            },
            required: ["action"],
          },
        });

        // Handle decline/cancel
        if (result.action !== "accept" || !result.content) {
          decisions.push({
            finding: finding.id,
            action: "skip",
            guidance: null,
            severity: finding.severity,
            title: finding.title,
          });
          if (result.action === "cancel") cancelled = true;
          decided = true;
          continue;
        }

        const action = (result.content as Record<string, unknown>)
          .action as string;

        // "View details" — show full body, then loop back to action menu
        if (action === "details") {
          await mcpServer.server.elicitInput({
            mode: "form",
            message:
              `── ${header} ──\n\n${finding.body}`,
            requestedSchema: {
              type: "object" as const,
              properties: {
                _ack: {
                  type: "boolean",
                  title: "Return to action menu",
                  default: true,
                },
              },
            },
          });
          // Loop back to action selection
          continue;
        }

        // "Fix with guidance" — collect guidance text
        let guidance: string | null = null;
        if (action === "fix_guided") {
          const guidanceResult = await mcpServer.server.elicitInput({
            mode: "form",
            message: `Guidance for fixing ${finding.id}: ${finding.title}`,
            requestedSchema: {
              type: "object" as const,
              properties: {
                guidance: {
                  type: "string",
                  title: "Guidance",
                  description:
                    "Instructions or context for fixing this finding",
                },
              },
              required: ["guidance"],
            },
          });
          if (
            guidanceResult.action === "accept" &&
            guidanceResult.content
          ) {
            guidance = (
              guidanceResult.content as Record<string, unknown>
            ).guidance as string;
          }
        }

        decisions.push({
          finding: finding.id,
          action: action as Action,
          guidance,
          severity: finding.severity,
          title: finding.title,
        });

        // Update file for accept/defer/ignore actions
        if (
          update_file &&
          (action === "accept" ||
            action === "defer" ||
            action === "ignore")
        ) {
          currentContent = markFinding(
            currentContent,
            finding,
            action as "accept" | "defer" | "ignore",
          );
          writeFileSync(absPath, currentContent, "utf-8");
          // Re-parse to get updated line numbers for subsequent findings
          const updatedFindings = parseFindings(currentContent);
          for (let j = i + 1; j < findings.length; j++) {
            const updated = updatedFindings.find(
              (f) => f.id === findings[j].id,
            );
            if (updated) {
              findings[j] = updated;
            }
          }
        }

        decided = true;
      }
    }

    // Build summary
    const summary = {
      total: findings.length,
      fix: decisions.filter((d) => d.action === "fix").length,
      fix_guided: decisions.filter((d) => d.action === "fix_guided").length,
      accept: decisions.filter((d) => d.action === "accept").length,
      defer: decisions.filter((d) => d.action === "defer").length,
      ignore: decisions.filter((d) => d.action === "ignore").length,
      skip: decisions.filter((d) => d.action === "skip").length,
    };

    const toFix = decisions.filter(
      (d) => d.action === "fix" || d.action === "fix_guided",
    );

    // Build result text
    let resultText = "## Triage Complete\n\n";
    resultText += `**${summary.total} findings triaged:**\n`;
    if (summary.fix > 0) resultText += `- ${summary.fix} to fix\n`;
    if (summary.fix_guided > 0)
      resultText += `- ${summary.fix_guided} to fix with guidance\n`;
    if (summary.accept > 0) resultText += `- ${summary.accept} accepted\n`;
    if (summary.defer > 0) resultText += `- ${summary.defer} deferred\n`;
    if (summary.ignore > 0) resultText += `- ${summary.ignore} ignored\n`;
    if (summary.skip > 0) resultText += `- ${summary.skip} skipped\n`;

    if (toFix.length > 0) {
      resultText += "\n### Findings to fix:\n\n";
      for (const d of toFix) {
        resultText += `**${d.finding}** ${d.severity} — ${d.title}\n`;
        if (d.guidance) {
          resultText += `  Guidance: ${d.guidance}\n`;
        }
        resultText += "\n";
      }
    }

    return {
      content: [
        {
          type: "text" as const,
          text: resultText,
        },
        {
          type: "text" as const,
          text: JSON.stringify({ decisions, summary }, null, 2),
        },
      ],
    };
  },
);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

async function main() {
  const transport = new StdioServerTransport();
  await mcpServer.connect(transport);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
