# Change log

## master (unreleased)

## 0.10.1

- Correctly determines the model class name of FactoryBot factories defined with
  an explicit `parent` parameter.

## 0.10.0

- EngineApiBoundary cop detects cross-engine use of FactoryBot factories.
- GlobalModelAccessFromEngine cop detects use of global FactoryBot factories.

## 0.9.0

- Add support for `_allowlist.rb`, in addition to `_whitelist.rb`.

## 0.8.0

- Bug fix related to disabling engines with similar names.

## 0.7.0

- Improved support for EngineSpecificOverrides in EngineApiBoundary cop.
