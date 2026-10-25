# UTM LiveContainer compatibility build

On iOS 26+ LiveContainer can assign a randomized bundle ID to UTM without updating the embedded iOSHelper ExtensionKit extension ID. iOS then rejects installation with `IXErrorDomain Code=8` and `Mismatched bundle IDs`.

## Experimental workaround

Download the official UTM IPA and run:

```sh
python3 scripts/livecontainer_ipa.py UTM.ipa UTM-LiveContainer.ipa
```

Import the resulting IPA into LiveContainer and use the usual JIT workflow. This repackages the IPA without the embedded `iOSHelper` extension. It does not bypass code signing, guarantee successful installation, or increase the amount of RAM available to QEMU.

**Limitations:** iOSHelper is required for some out-of-process QEMU tools on iOS 26+, including disk snapshots, resizing, and conversion. These operations may be unavailable. Use the normal UTM IPA when these features are required.

For a full fix, LiveContainer should rewrite and re-sign nested extension identifiers consistently when it rewrites the host bundle ID, and provide the appropriate extension provisioning profile.
