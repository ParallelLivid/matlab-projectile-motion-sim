# Contributing

Thanks for helping improve the Projectile Motion Simulator.

## Development setup

Use MATLAB R2025b or a compatible newer release. Clone the repository, open
MATLAB in the repository root, and launch the app with:

```matlab
projectile_simulator
```

The project uses base MATLAB and does not require third-party toolboxes.

## Before opening a pull request

Run the automated tests:

```matlab
results = runtests("tests");
assertSuccess(results);
```

Run MATLAB Code Analyzer on the production code and screenshot generator:

```matlab
files = ["projectile_physics.m", "projectile_simulator.m", "examples.m"];
assert(all(arrayfun(@(file) isempty(checkcode(file,"-id")),files)));
```

For UI changes, manually exercise Run, Stop, Replay, Reset, comparison mode,
the scrubber, and fullscreen. Regenerate the README screenshots with
`examples` when the visible interface or sample results change.

Keep pull requests focused and include tests for changes to physics,
termination behavior, validation, or solver resource limits.
