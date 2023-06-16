create-tag-from-cargo-toml
=====

Create and push a Git tag (which can be used to trigger a release workflow)  from the version in the Rust manifest file (cargo.toml)

## Inputs

| Name               | Description                                                                                                            | Required | Default |
|--------------------|------------------------------------------------------------------------------------------------------------------------|----------|---------|
| github-token       | The GitHub token to use to push the tag. Use `{{ secrets.GITHUB_TOKEN }}` to use the token provided by GitHub Actions. | Required |         |
| path-to-cargo-toml | The path to the `Cargo.toml` file to generate documentation for. If not specified, assumes `Cargo.toml`.               | No       |         |

`create-tag-from-cargo-toml` is a GitHub Action that creates a tag from a Rust project's `Cargo.toml` file.
