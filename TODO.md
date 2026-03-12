# SwaggerSwift Code Review

**Judge: Senior Swift Engineer**

## 🔴 Critical (2 issues)

| # | File(s) | Issue | Fix |
|---|---------|-------|-----|
| 1 | `ObjectModelFactory.swift:10` | **IUO crash risk**: `public var modelTypeResolver: ModelTypeResolver!` — crash if accessed before assignment | Break circular dep with a protocol |
| 2 | `APIRequest+Swiftable.swift:183,185,213,303` | **Force unwraps/casts in generated client code** (`URLComponents!`, `url!`, `fatalError`, `as!`) — crash risk in production iOS apps | Generate guard-let + throw patterns |

## 🟠 High (3 issues)

| # | File(s) | Issue | Fix |
|---|---------|-------|-----|
| 1 | `Logger.swift:28`, `Generator.swift:33` | **Global mutable `isVerboseMode`** mutated in async context — data race | Pass verbose flag through call chain or use `TaskLocal` |
| 2 | `Generator.swift:187` | **Network error silently discarded** — swallowed `_` in dataTask closure | Capture and propagate the actual error |
| 3 | `Generator.swift:186` | **Manual async bridge** wrapping dataTask — unnecessary since macOS 12 has native `URLSession.data(for:)` | Replace with native async API |

## 🟢 Low (6 issues)

| # | File(s) | Issue | Fix |
|---|---------|-------|-----|
| 1 | `Generator.swift:353` | **DRY**: `createCommonLibrary` repeats `replacingOccurrences + write` 10 times | Extract helper function |
| 2 | `SafePropertyName`/`SafeParameterName` | **Identical duplicated structs** | Consolidate into single `SafeName` type |
| 3 | `Generator.swift:204` | **Unused parameter**: `urlSession` passed but `URLSession.shared` always used | Remove or use the parameter |
| 4 | `Generator.swift` | **SRP violation**: Generator handles download, parsing, file I/O, and package creation | Extract `SwaggerDownloader`, `FileWriter` |
| 5 | Tests/ | **Minimal test coverage** — only 2 model tests + resolver tests; no factory/generator tests | Add snapshot tests for code generation |
| 6 | `APIRequestResponseType.swift:98-177` | **DRY**: int/double/float/boolean/int64 response cases nearly identical (~80 lines) | Extract shared `parsePrimitive` helper |

## Effort Estimates

- **M (1–3h)**: Replace positional token arg with env var/stdin; remove `fatalError` hot paths
- **L (1–2d)**: Remove IUO circular dependency; rework generated code to avoid `as!` and `!`; add snapshot tests
- **XL (>2d)**: Introduce intermediate representation for codegen
