# SwaggerSwift

A Swift code generator that turns **Swagger (OpenAPI 2.0)** specs into a fully typed, async/await-ready networking layer — complete with models, API clients, and an optional Swift Package.

Point it at your backend services, and it downloads the specs from GitHub and generates everything you need to start making network calls.

## How It Works

```
SwaggerFile.yml ─┐
                 ├─▶ SwaggerSwift ─▶ 📦 Swift Package
GitHub Specs ────┘        │
                          ├── API Clients     (one per service)
                          ├── Models          (structs, enums, typealiases)
                          └── Shared Library  (ServiceError, NetworkInterceptor, …)
```

## Installation

### Build from source

```bash
git clone https://github.com/lunarway/swaggerswift.git
cd swaggerswift
swift build -c release
# Binary is at .build/release/swaggerswift
```

## Usage

1. Create a `SwaggerFile.yml` in your project root:

```yaml
path: docs/swagger.json            # Path to Swagger spec in each repo
organisation: lunarway              # GitHub organisation
destination: ./Generated            # Where to write the output
projectName: MyAPI                  # Name of the generated Swift Package
createSwiftPackage: true            # Generate a full Package.swift
accessControl: public               # public | internal | private
onlyAsync: true                     # Only generate async/await methods
globalHeaders:                       # Headers injected into every request
  - Authorization
  - Accept-Language
services:
  user-service:                      # Repo name on GitHub
    branch: main                     # Branch to pull spec from (default: master)
  payment-service: {}
  notification-service:
    path: api/swagger.yaml           # Override spec path for this service
```

2. Run the generator:

```bash
export GITHUB_TOKEN="ghp_…"
swaggerswift --swagger-file-path ./SwaggerFile.yml
```

### CLI Options

| Flag | Description |
|---|---|
| `-s, --swagger-file-path` | Path to `SwaggerFile.yml` (default: `./SwaggerFile`) |
| `-g, --git-hub-token` | GitHub token (or use `GITHUB_TOKEN` env var) |
| `-v, --verbose` | Enable verbose logging |
| `-a, --api-list` | Comma-separated list of services to generate |

## Generated Output

Given a `SwaggerFile.yml` with two services, you get:

```
Generated/
└── MyAPI/
    ├── Package.swift
    └── Sources/
        ├── MyAPIShared/          # Common networking utilities
        │   ├── ServiceError.swift
        │   ├── NetworkInterceptor.swift
        │   ├── APIInitialize.swift
        │   ├── GlobalHeaders.swift
        │   ├── FormData.swift
        │   ├── DateDecodingStrategy.swift
        │   └── …
        ├── UserService/
        │   ├── UserService.swift         # API client with async methods
        │   └── Models/
        │       ├── UserService_User.swift
        │       └── UserService_CreateUserRequest.swift
        └── PaymentService/
            ├── PaymentService.swift
            └── Models/
                └── …
```

### What gets generated

- **API Clients** — One struct per service with a method per endpoint. Supports query, path, header, and body parameters. Returns typed `Result<SuccessType, ServiceError<ErrorType>>`.
- **Models** — Structs, enums, and typealiases derived from Swagger definitions and inline schemas, with protocol conformance optimized by usage direction (`Encodable` for request-only models, `Decodable` for response-only models, and `Codable` when used in both directions).
- **Shared Library** — Networking boilerplate: `ServiceError`, `NetworkInterceptor`, `GlobalHeaders`, `FormData`, `AdditionalProperty`, JSON date decoding, and URL query extensions.

## Requirements

- **Swift 5.9+**
- **macOS 12+**
- A GitHub personal access token with repo read access

## Known Limitations

- OpenAPI 2.0 (Swagger) only — OpenAPI 3.x is not supported
- No support for dictionary types (`additionalProperties` with typed values)
- Object inheritance is flattened (fields are inlined into concrete types)
