# XPalm.VPalm submodule API

`VPalm` is loaded explicitly because the physiological XPalm simulation path
does not need the full geometry and biomechanics stack:

```julia
using XPalm
VPalm = XPalm.load_vpalm!()
```

```@autodocs
Modules = [XPalm.VPalm]
```
