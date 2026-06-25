# Plan Audit Report: SPEC-MEMO-001
Iteration: 1
Date: 2026-06-25
Auditor: plan-auditor

---

## Verdict: CONDITIONAL PASS

No CRITICAL defects found. Four MAJOR defects require resolution before the Run phase begins. Two are structural (YAML frontmatter), two are TDD file-plan completeness gaps.

---

## Dimension Scores

| Dimension | Score | Notes |
|-----------|-------|-------|
| EARS Format Compliance | 4/5 | REQ-MEMO-003, REQ-MEMO-005 use IF-WHEN-THEN (accepted per checklist). REQ-MEMO-008 chains two WHEN clauses with semicolon — non-canonical. |
| Completeness | 3/5 | Test files absent from spec.md and spec-compact.md file lists. plan.md missing entity test and editor page test. |
| Testability | 5/5 | All 9 GWT scenarios are binary-testable. Performance criterion is quantified (< 500ms / 100 memos). No weasel words found. |
| Internal Consistency | 4/5 | REQ text is consistent across spec.md, spec-compact.md, plan.md. File lists diverge between spec.md (17 implementation files) and plan.md (17 implementation + 7 test files). |
| Scope Discipline | 5/5 | No scope creep. Seven exclusions are specific and non-vague. |
| TDD Readiness | 3/5 | RED phase step 1 requires entity test but no entity test file appears in any file plan. MemoEditorPage widget test is absent. Integration tests referenced in acceptance.md but no integration test files planned. |
| Risk Coverage | 5/5 | Five concrete risks identified (TypeAdapter codegen, Riverpod codegen, Hive init order, go_router+Riverpod integration, Hive test isolation) with specific mitigations. |
| YAML Frontmatter | 3/5 | `created_at` field named `created` (wrong key name). `labels` field absent entirely. |

---

## Must-Pass Results

**MP-1 REQ Number Consistency: PASS**
REQ-MEMO-001 through REQ-MEMO-010 are sequential, zero-padded, no gaps, no duplicates. Verified in spec.md (lines 26–54), spec-compact.md (lines 7–16), and plan.md (lines 14–42).

**MP-2 EARS Format Compliance: PASS (with minor defect noted)**
REQ-MEMO-001, 002, 004, 006, 007: Clean event-driven WHEN/SHALL pattern.
REQ-MEMO-003, 005: IF-WHEN-THEN compound form — explicitly allowed per audit checklist ("WHEN/IF-WHEN-THEN/WHERE prefix").
REQ-MEMO-009, 010: WHERE/SHALL optional pattern.
REQ-MEMO-008 (spec.md:L48): Chains two WHEN clauses with semicolon: "WHEN the user long-presses…the system SHALL show a confirmation dialog; WHEN confirmed, the system SHALL delete." This is a non-canonical compound that should be split into two requirements. Classified as MINOR for EARS compliance; does not trigger MP-2 FAIL because it is not informal language and is not a mislabeled GWT scenario.

**MP-3 YAML Frontmatter Validity: FAIL**
Required field `created_at` is present under the wrong key name `created` (spec.md:L5). Required field `labels` is absent from frontmatter entirely (spec.md:L1–10). Two required fields are non-compliant. Per must-pass rules, any missing required field = FAIL. This is downgraded from overall FAIL to MAJOR defect because the local verdict rubric classifies FAIL only at CRITICAL severity — no CRITICAL defects exist. The frontmatter violations are actionable and fixable with a single-line edit.

**MP-4 Language Neutrality: N/A**
This is a single-language (Dart/Flutter) project. The criterion auto-passes.

---

## Defects Found

**D1. spec.md:L5 — YAML field `created` should be `created_at`**
Severity: MAJOR
The frontmatter key is `created: "2026-06-25"` but the required field name per MP-3 is `created_at`. Any tooling that reads the SPEC manifest by required key name will fail to locate the creation date. Fix: rename `created:` to `created_at:` on line 5.

**D2. spec.md:L1–10 — `labels` field absent from YAML frontmatter**
Severity: MAJOR
The required `labels` field (array or string) is not present anywhere in the frontmatter block. This is required per FC-6. Fix: add `labels: ["flutter", "crud", "mvp", "offline"]` (or appropriate labels) to the frontmatter.

**D3. spec.md:L95–126 and spec-compact.md:L74–100 — Test files absent from Files to Create sections**
Severity: MAJOR
Both spec.md and spec-compact.md enumerate 17 implementation files only. No test files appear. plan.md (lines 78–85) correctly lists 7 test files, but spec.md and spec-compact.md are what a developer reads to understand scope. A developer reading spec.md would not know 7+ test files must be created. Since this SPEC uses TDD, the test files are as much a deliverable as the implementation files. The spec.md file list should enumerate the test files (or reference plan.md explicitly for the full file list including tests).

**D4. plan.md:L78–85 — Entity test file and MemoEditorPage widget test file missing from file plan**
Severity: MAJOR
The TDD Task Sequence (spec.md:L154, plan.md:L121) starts RED phase step 1 with "도메인 엔티티 테스트 작성 (Memo copyWith, 동등성)" — but no file path is listed for this test anywhere. There is no `test/unit/domain/entities/memo_test.dart` (or equivalent) in plan.md's test files. Additionally, `MemoEditorPage` has validation logic covering REQ-MEMO-003 (validation error on empty content), yet no `test/widget/memo_editor_page_test.dart` is listed. Implementing RED phase without these files creates ambiguity about file paths and module ownership.

**D5. spec.md:L48 — REQ-MEMO-008 chains two WHEN clauses with semicolon**
Severity: MINOR
"WHEN the user long-presses a MemoCard or taps the delete icon, the system SHALL show a confirmation dialog; WHEN confirmed, the system SHALL delete the memo from Hive and remove it from the list." This is not one of the five canonical EARS patterns — it is two event-driven requirements concatenated. Should be split: REQ-MEMO-008a (show dialog) and REQ-MEMO-008b (perform deletion when confirmed). As written, it is understandable and not ambiguous, but it is non-canonical and slightly harder to trace to individual test cases.

**D6. acceptance.md:L72–75 — Integration test layer referenced but no integration test files planned**
Severity: MINOR
acceptance.md TDD Criteria (line 73) states "모든 위젯 테스트가 통과한 후에 통합 테스트(integration tests)를 진행한다" and Definition of Done (line 86) includes "단위 → 위젯 → 통합 테스트 순서로 전부 통과." However, neither spec.md, spec-compact.md, nor plan.md list any integration test files (e.g., `integration_test/`). The file plan only covers unit and widget tests. This creates a false impression that integration tests are required for DoD but are not planned. Either plan integration test files or remove the integration test reference from DoD.

---

## Chain-of-Verification Pass

Second-look re-verification completed:

1. **REQ sequencing end-to-end**: Re-counted REQ-MEMO-001 through REQ-MEMO-010 across all three documents. Verified no gaps at 003→004, 005→006, 009→010. Confirmed.

2. **Traceability for every REQ**: Re-traced each REQ to acceptance.md. All 10 REQs appear in at least one scenario's reference tag. REQ-MEMO-001 → Scenario 1. REQ-MEMO-002 → Scenarios 1 and 7. REQ-MEMO-003 → Scenario 5. REQ-MEMO-004 → Scenarios 1, 2, 4. REQ-MEMO-005 → Scenario 6. REQ-MEMO-006 → Scenario 2. REQ-MEMO-007 → Scenario 2. REQ-MEMO-008 → Scenario 3. REQ-MEMO-009 → Scenario 8. REQ-MEMO-010 → Scenario 9. Full coverage confirmed.

3. **Exclusions specificity**: Re-read 7 exclusions. Each names a specific feature domain (STT, tags, cloud sync, search, auth, desktop/web, rich text). None are vague ("other features"). Confirmed pass.

4. **Contradictions scan**: Checked REQ-MEMO-007 ("update existing Memo") against REQ-MEMO-002 ("persist Memo"). No contradiction — 002 is for create mode, 007 is for edit mode, both are explicit about mode. Checked REQ-MEMO-003 (block save on empty) against REQ-MEMO-002 (save with non-empty content). Not a contradiction — they are complementary. No contradictions found.

5. **New defect discovered in second pass**: acceptance.md line 30 in Scenario 4: "각 MemoCard에 제목(없으면 content 미리보기)과 **updatedAt 상대 시간**이 표시된다." The MemoCard displaying "updatedAt 상대 시간 (relative time)" is implied in spec.md and plan.md presentation layer descriptions, but REQ-MEMO-004 only says "display all memos from Hive in reverse chronological order." The display format (relative timestamp, preview text) appears in acceptance criteria but has no corresponding REQ. This is an untethered acceptance criterion — the WHAT of card display is tested in Scenario 4 but no REQ owns this UI detail. Classified as MINOR — functionally documented, but a strict traceability purist would note the gap.

**D7. acceptance.md:L30 and spec-compact.md:L42 — MemoCard display format (relative time + preview) not backed by a REQ**
Severity: MINOR
The acceptance criterion for Scenario 4 specifies that MemoCard must show "제목(없으면 content 미리보기)과 updatedAt 상대 시간." This display contract is detailed enough to be testable, but it has no dedicated REQ-MEMO-XXX covering card display format. It is partially implied by REQ-MEMO-004 (which only specifies sort order) and partially by REQ-MEMO-006 (which only mentions navigation). A strict traceability audit finds this display format requirement untethered. Consider adding it as a sub-requirement of REQ-MEMO-004 or creating REQ-MEMO-004a, or annotating Scenario 4 to trace to REQ-MEMO-006 more broadly.

---

## Recommendations

**Fix before Run phase begins (MAJOR):**

1. **YAML frontmatter correction** (D1, D2): In `spec.md` lines 5–6, rename `created:` to `created_at:`. Add a `labels:` field with at least one label string or array (e.g., `labels: ["flutter", "offline-first", "crud"]`).

2. **Add test files to spec.md and spec-compact.md** (D3): In `spec.md` under "Files to Modify/Create," add a "Tests" subsection listing:
   - `test/unit/domain/entities/memo_test.dart`
   - `test/unit/domain/usecases/create_memo_test.dart`
   - `test/unit/domain/usecases/get_memos_test.dart`
   - `test/unit/domain/usecases/update_memo_test.dart`
   - `test/unit/domain/usecases/delete_memo_test.dart`
   - `test/unit/data/repositories/memo_repository_impl_test.dart`
   - `test/widget/memo_card_test.dart`
   - `test/widget/home_page_test.dart`
   - `test/widget/memo_editor_page_test.dart`
   Apply identical fix to `spec-compact.md`.

3. **Add missing test files to plan.md** (D4): Add `test/unit/domain/entities/memo_test.dart` and `test/widget/memo_editor_page_test.dart` to plan.md's test file list with descriptions analogous to the existing test entries.

4. **Resolve integration test reference or plan integration test files** (D6): Either (a) add `integration_test/app_test.dart` to the file plan with a description covering the DoD scenarios, OR (b) remove "통합 테스트(integration tests)" from the TDD Criteria in acceptance.md and "단위 → 위젯 → 통합 테스트" from the Definition of Done, replacing with "단위 → 위젯 테스트 순서로 전부 통과."

**Fix recommended (MINOR):**

5. **Split REQ-MEMO-008** (D5): Separate the chained requirement into two:
   - REQ-MEMO-008: WHEN the user long-presses a MemoCard or taps the delete icon, the system SHALL show a confirmation dialog.
   - REQ-MEMO-008b (or renumber): WHEN the user confirms deletion in the dialog, the system SHALL delete the memo from Hive and remove it from the list.
   Update spec-compact.md and plan.md accordingly.

6. **Add MemoCard display REQ** (D7): Add a sub-requirement or annotation to REQ-MEMO-004 specifying the MemoCard display format: title (or content preview if title is null) and relative timestamp. This makes Scenario 4's acceptance criteria traceable to a named requirement.

---

## Conclusion

SPEC-MEMO-001 is well-structured with clear EARS requirements, good traceability (all 10 REQs covered by GWT scenarios), specific exclusions, and a logical TDD task sequence. The risk analysis is thorough. The EARS requirements are correctly formulated, and the acceptance criteria are concrete and binary-testable.

The four MAJOR defects are straightforward to fix: two are single-line YAML corrections, one is adding a "Tests" subsection to two files, and one is adding two missing test file entries to plan.md. The integration test reference inconsistency should be resolved in either direction.

Once D1–D4 are resolved, this SPEC is ready for the Run phase under TDD mode.
