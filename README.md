# Green Window

When should you start that appliance? Green Window finds the cleanest time to run it on your part of the GB grid, and makes sure it's finished when you need it.

Work in progress. See [docs/PRD.md](docs/PRD.md) for what it does and [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for how it's being built. The full README lands in Phase 7.

## Run it

Flutter is pinned with [fvm](https://fvm.app) (`.fvmrc`).

```bash
fvm install
fvm flutter pub get
fvm flutter run -d chrome --wasm
```

## Check it

```bash
fvm dart format .
fvm dart analyze --fatal-infos
fvm flutter test
fvm flutter build web --wasm
```

Data: [Carbon Intensity API](https://carbonintensity.org.uk/), National Energy System Operator, CC BY 4.0.
