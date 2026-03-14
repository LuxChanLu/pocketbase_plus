# Priority Feature Recommendations

## High Priority (Most Needed)

1. Relation Field Support
   - Currently generates dynamic for relation fields (e.g., user1, chat, sender)
   - Should generate typed relations with optional expand support
   - Most impactful for real-world apps with collections referencing each other
2. Additional Field Types
   - file - File uploads (single/multiple), URL builders
   - email - Email addresses with validation
   - url - URL fields
   - editor - Rich text content
   - json - Dynamic JSON fields
   - datetime - Already exists in SDK, not generated
3. CRUD Helper Methods (Stated in README as TODO)
   - create(), update(), delete() instance methods
   - Model-aware serialization

## Medium Priority

4. Static List/Fetch Methods (Stated in README as TODO)
   - Model.getList(), Model.getOne(), Model.getFullList()
   - Typed filtering/pagination
5. Expand/Relation Parsing
   - Parse expand data into typed nested models
   - r.get<RecordModel>('expand.user') patterns
6. Barrel File Export
   - Generate models.dart that exports all models

## Lower Priority (Nice to Have)

7. Realtime subscription helpers
8. Batch operation wrappers
9. Type-safe filter builders
10. Auth model specialization
