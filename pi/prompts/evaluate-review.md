---
description: Evaluate landed code reviews and propose two equally strong solutions
argument-hint: "<review location: PR number/URL or path to review notes>"
---
Review(s) have landed for this feature — source: $ARGUMENTS
(If no source is given, ask me where the reviews are before doing anything else.)

Analyse all of them. If the source is a PR number/URL, fetch the review comments
yourself; if it is a path, read it.

Then propose exactly two distinct solutions for me to consider. Each may be code or
a rebuttal (including rebutting specific review comments), and each must be
justified, with an indication of complexity and any downstream impact on security,
performance, or our codebase rules. A rebuttal must cite evidence — code, tests, or
repo rules — rather than merely assert disagreement.

Both solutions must be independently high-quality: both defensible as your best.
Do not offer an obviously bad option next to a good one.

Propose only; do not implement anything until I choose.
