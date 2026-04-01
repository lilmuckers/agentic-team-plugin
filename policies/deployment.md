# Deployment Policy

Deploy framework changes from reviewed commits on `main` into a separate active copy.

## Principles
- Active deployment should not be used as a scratch working tree
- Promotion should happen through staging, validation, and then activation
- Failed validation should leave the current active deployment untouched
- Every deployment should record the commit SHA and timestamp

## Recommended deployment sequence
1. fetch reviewed commit from `main`
2. checkout into staging
3. validate framework contents
4. promote to active copy
5. record deployed SHA and metadata
