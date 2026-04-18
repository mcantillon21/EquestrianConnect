#!/usr/bin/env python3
"""
Generates a minimal but valid Xcode project for EquestrianConnect.
Run: python3 generate_project.py
"""
import os
import uuid
import re

BASE = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(BASE, "EquestrianConnect")
XCODEPROJ = os.path.join(BASE, "EquestrianConnect.xcodeproj")

# Preserve the DEVELOPMENT_TEAM from the existing project so Xcode
# doesn't ask for re-signing after every regeneration.
def read_existing_team():
    pbx = os.path.join(XCODEPROJ, "project.pbxproj")
    if not os.path.exists(pbx):
        return '""'
    with open(pbx, encoding="utf-8") as f:
        for line in f:
            m = re.search(r'DEVELOPMENT_TEAM\s*=\s*([^;]+);', line)
            if m:
                val = m.group(1).strip()
                if val and val != '""' and val != "":
                    return val
    return '""'

EXISTING_TEAM = read_existing_team()

def fresh_id():
    return uuid.uuid4().hex[:24].upper()

# Collect all Swift source files relative to APP_DIR
def collect_sources():
    sources = []
    for root, dirs, files in os.walk(APP_DIR):
        # Skip xcassets internals
        if ".xcassets" in root:
            continue
        for f in files:
            if f.endswith((".swift", ".plist", ".csv")):
                rel = os.path.relpath(os.path.join(root, f), APP_DIR)
                sources.append(rel)
    return sorted(sources)

def collect_xcassets():
    return ["Assets.xcassets"]

sources = collect_sources()
xcassets = collect_xcassets()

# External (non-EquestrianConnect/) files wired into the project.
XCCONFIG_REL = "Config/Supabase.xcconfig"
XCCONFIG_ABS = os.path.join(BASE, XCCONFIG_REL)
if not os.path.exists(XCCONFIG_ABS):
    print(f"⚠️  {XCCONFIG_REL} is missing — copy Config/Supabase.xcconfig.example and fill it in before building.")

# Generate UUIDs for everything
PROJECT_ID     = fresh_id()
TARGET_ID      = fresh_id()
MAIN_GROUP_ID  = fresh_id()
PRODUCTS_ID    = fresh_id()
PRODUCT_REF_ID = fresh_id()
BUILD_FILES_CONFIG_LIST = fresh_id()
PROJECT_CONFIG_LIST     = fresh_id()
DEBUG_BUILD_CONFIG_ID   = fresh_id()
RELEASE_BUILD_CONFIG_ID = fresh_id()
DEBUG_PROJECT_CONFIG_ID = fresh_id()
RELEASE_PROJECT_CONFIG_ID = fresh_id()
SOURCES_PHASE_ID        = fresh_id()
RESOURCES_PHASE_ID      = fresh_id()
FRAMEWORKS_PHASE_ID     = fresh_id()

# Per-file IDs
file_refs = {}   # rel_path -> fileRef UUID
build_files = {} # rel_path -> buildFile UUID (swift only)
asset_ref_id = fresh_id()
asset_build_file_id = fresh_id()
xcconfig_ref_id = fresh_id()

resource_build_files = {}  # rel_path -> buildFile UUID (non-swift resources like .csv)

for s in sources:
    file_refs[s] = fresh_id()
    if s.endswith(".swift"):
        build_files[s] = fresh_id()
    elif s.endswith(".csv"):
        resource_build_files[s] = fresh_id()

# Group structure
def make_group_tree(sources):
    """Return nested dict representing folder hierarchy."""
    tree = {}
    for s in sources:
        parts = s.split(os.sep)
        node = tree
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        node[parts[-1]] = None
    return tree

# We'll emit groups recursively
group_ids = {}  # path -> UUID

def assign_group_ids(tree, prefix=""):
    for name, subtree in tree.items():
        path = os.path.join(prefix, name) if prefix else name
        if subtree is not None:
            # It's a folder
            group_ids[path] = fresh_id()
            assign_group_ids(subtree, path)

tree = make_group_tree(sources)
assign_group_ids(tree)

lines = []

def emit(s, indent=0):
    lines.append("\t" * indent + s)

emit("// !$*UTF8*$!")
emit("{")
emit("archiveVersion = 1;", 1)
emit("classes = {", 1)
emit("};", 1)
emit("objectVersion = 56;", 1)
emit("objects = {", 1)
emit("")

# PBXBuildFile
emit("/* Begin PBXBuildFile section */", 2)
for s, bid in build_files.items():
    fname = os.path.basename(s)
    fref = file_refs[s]
    emit(f"{bid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {fname} */; }};", 3)
# xcassets
emit(f"{asset_build_file_id} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {asset_ref_id} /* Assets.xcassets */; }};", 3)
# CSV and other bundled resources
for s, bid in resource_build_files.items():
    fname = os.path.basename(s)
    fref = file_refs[s]
    emit(f"{bid} /* {fname} in Resources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {fname} */; }};", 3)
emit("/* End PBXBuildFile section */", 2)
emit("")

# PBXFileReference
emit("/* Begin PBXFileReference section */", 2)
for s, fid in file_refs.items():
    fname = os.path.basename(s)
    if fname.endswith(".swift"):
        ltype = "sourcecode.swift"
        etype = "sourcecode.swift"
    elif fname == "Info.plist":
        ltype = "text.plist.xml"
        etype = "text.plist.xml"
    elif fname.endswith(".csv"):
        ltype = "text.csv"
        etype = "text.csv"
    else:
        ltype = "text"
        etype = "text"
    emit(f'{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = {ltype}; path = "{fname}"; sourceTree = "<group>"; }};', 3)
# xcassets
emit(f'{asset_ref_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};', 3)
# xcconfig (lives at repo root, outside EquestrianConnect/)
emit(f'{xcconfig_ref_id} /* Supabase.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = Supabase.xcconfig; path = "{XCCONFIG_REL}"; sourceTree = SOURCE_ROOT; }};', 3)
# Product
emit(f'{PRODUCT_REF_ID} /* EquestrianConnect.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = EquestrianConnect.app; sourceTree = BUILT_PRODUCTS_DIR; }};', 3)
emit("/* End PBXFileReference section */", 2)
emit("")

# PBXFrameworksBuildPhase
emit("/* Begin PBXFrameworksBuildPhase section */", 2)
emit(f"{FRAMEWORKS_PHASE_ID} /* Frameworks */ = {{", 3)
emit("isa = PBXFrameworksBuildPhase;", 4)
emit("buildActionMask = 2147483647;", 4)
emit("files = (", 4)
emit(");", 4)
emit("runOnlyForDeploymentPostprocessing = 0;", 4)
emit("};", 3)
emit("/* End PBXFrameworksBuildPhase section */", 2)
emit("")

# PBXGroup - build recursively
emit("/* Begin PBXGroup section */", 2)

def emit_group(name, subtree, parent_path, indent_level, path_from_parent=None):
    path = os.path.join(parent_path, name) if parent_path else name
    gid = group_ids.get(path, fresh_id())

    emit(f"{gid} /* {name} */ = {{", indent_level)
    emit("isa = PBXGroup;", indent_level + 1)
    emit("children = (", indent_level + 1)

    # Sub-folders first
    for child_name, child_tree in sorted(subtree.items(), key=lambda x: (x[1] is None, x[0])):
        child_path = os.path.join(path, child_name)
        if child_tree is not None:
            child_gid = group_ids.get(child_path, fresh_id())
            emit(f"{child_gid} /* {child_name} */,", indent_level + 2)
        else:
            # File
            file_rel = child_path
            if file_rel in file_refs:
                fid = file_refs[file_rel]
                emit(f"{fid} /* {child_name} */,", indent_level + 2)

    emit(");", indent_level + 1)
    emit(f'name = "{name}";', indent_level + 1)
    if path_from_parent:
        emit(f'path = "{path_from_parent}";', indent_level + 1)
    else:
        emit(f'path = "{name}";', indent_level + 1)
    emit("sourceTree = \"<group>\";", indent_level + 1)
    emit("};", indent_level)

    # Recurse into sub-groups
    for child_name, child_tree in subtree.items():
        if child_tree is not None:
            child_path = os.path.join(path, child_name)
            emit_group(child_name, child_tree, path, indent_level, child_name)

# Main group
emit(f"{MAIN_GROUP_ID} = {{", 3)
emit("isa = PBXGroup;", 4)
emit("children = (", 4)
# Top-level items in APP_DIR
for name, subtree in sorted(tree.items(), key=lambda x: (x[1] is None, x[0])):
    if subtree is not None:
        child_path = name
        gid = group_ids.get(child_path, "")
        emit(f"{gid} /* {name} */,", 5)
    else:
        file_rel = name
        if file_rel in file_refs:
            fid = file_refs[file_rel]
            emit(f"{fid} /* {name} */,", 5)
# xcassets
emit(f"{asset_ref_id} /* Assets.xcassets */,", 5)
emit(f"{xcconfig_ref_id} /* Supabase.xcconfig */,", 5)
emit(f"{PRODUCTS_ID} /* Products */,", 5)
emit(");", 4)
emit('name = EquestrianConnect;', 4)
emit('path = EquestrianConnect;', 4)
emit('sourceTree = "<group>";', 4)
emit("};", 3)

# Products group
emit(f"{PRODUCTS_ID} /* Products */ = {{", 3)
emit("isa = PBXGroup;", 4)
emit("children = (", 4)
emit(f"{PRODUCT_REF_ID} /* EquestrianConnect.app */,", 5)
emit(");", 4)
emit('name = Products;', 4)
emit('sourceTree = "<group>";', 4)
emit("};", 3)

# Sub-groups
for name, subtree in tree.items():
    if subtree is not None:
        emit_group(name, subtree, "", 3, name)

emit("/* End PBXGroup section */", 2)
emit("")

# PBXNativeTarget
emit("/* Begin PBXNativeTarget section */", 2)
emit(f"{TARGET_ID} /* EquestrianConnect */ = {{", 3)
emit("isa = PBXNativeTarget;", 4)
emit(f"buildConfigurationList = {BUILD_FILES_CONFIG_LIST} /* Build configuration list for PBXNativeTarget EquestrianConnect */;", 4)
emit("buildPhases = (", 4)
emit(f"{SOURCES_PHASE_ID} /* Sources */,", 5)
emit(f"{FRAMEWORKS_PHASE_ID} /* Frameworks */,", 5)
emit(f"{RESOURCES_PHASE_ID} /* Resources */,", 5)
emit(");", 4)
emit("buildRules = (", 4)
emit(");", 4)
emit("dependencies = (", 4)
emit(");", 4)
emit('name = EquestrianConnect;', 4)
emit('productName = EquestrianConnect;', 4)
emit(f'productReference = {PRODUCT_REF_ID} /* EquestrianConnect.app */;', 4)
emit('productType = "com.apple.product-type.application";', 4)
emit("};", 3)
emit("/* End PBXNativeTarget section */", 2)
emit("")

# PBXProject
emit("/* Begin PBXProject section */", 2)
emit(f"{PROJECT_ID} /* Project object */ = {{", 3)
emit("isa = PBXProject;", 4)
emit("attributes = {", 4)
emit("BuildIndependentTargetsInParallel = 1;", 5)
emit("LastSwiftUpdateCheck = 1500;", 5)
emit("LastUpgradeCheck = 1500;", 5)
emit("TargetAttributes = {", 5)
emit(f"{TARGET_ID} = {{", 6)
emit("CreatedOnToolsVersion = 15.0;", 7)
emit("};", 6)
emit("};", 5)
emit("};", 4)
emit(f"buildConfigurationList = {PROJECT_CONFIG_LIST} /* Build configuration list for PBXProject EquestrianConnect */;", 4)
emit('compatibilityVersion = "Xcode 14.0";', 4)
emit('developmentRegion = en;', 4)
emit('hasScannedForEncodings = 0;', 4)
emit('knownRegions = (', 4)
emit('en,', 5)
emit('Base,', 5)
emit(');', 4)
emit(f'mainGroup = {MAIN_GROUP_ID};', 4)
emit(f'productRefGroup = {PRODUCTS_ID} /* Products */;', 4)
emit('projectDirPath = "";', 4)
emit('projectRoot = "";', 4)
emit('targets = (', 4)
emit(f'{TARGET_ID} /* EquestrianConnect */,', 5)
emit(');', 4)
emit("};", 3)
emit("/* End PBXProject section */", 2)
emit("")

# PBXResourcesBuildPhase
emit("/* Begin PBXResourcesBuildPhase section */", 2)
emit(f"{RESOURCES_PHASE_ID} /* Resources */ = {{", 3)
emit("isa = PBXResourcesBuildPhase;", 4)
emit("buildActionMask = 2147483647;", 4)
emit("files = (", 4)
emit(f"{asset_build_file_id} /* Assets.xcassets in Resources */,", 5)
for s, bid in sorted(resource_build_files.items()):
    fname = os.path.basename(s)
    emit(f"{bid} /* {fname} in Resources */,", 5)
emit(");", 4)
emit("runOnlyForDeploymentPostprocessing = 0;", 4)
emit("};", 3)
emit("/* End PBXResourcesBuildPhase section */", 2)
emit("")

# PBXSourcesBuildPhase
emit("/* Begin PBXSourcesBuildPhase section */", 2)
emit(f"{SOURCES_PHASE_ID} /* Sources */ = {{", 3)
emit("isa = PBXSourcesBuildPhase;", 4)
emit("buildActionMask = 2147483647;", 4)
emit("files = (", 4)
for s, bid in sorted(build_files.items()):
    fname = os.path.basename(s)
    emit(f"{bid} /* {fname} in Sources */,", 5)
emit(");", 4)
emit("runOnlyForDeploymentPostprocessing = 0;", 4)
emit("};", 3)
emit("/* End PBXSourcesBuildPhase section */", 2)
emit("")

# XCBuildConfiguration
emit("/* Begin XCBuildConfiguration section */", 2)

common_settings = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": EXISTING_TEAM,
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "EquestrianConnect/Info.plist",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MARKETING_VERSION": "1.0.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.equestrianconnect.app",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SDKROOT": "iphoneos",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1"',
}

debug_extra = {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}

release_extra = {
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Owholemodule"',
    "VALIDATE_PRODUCT": "YES",
}

def emit_build_config(config_id, name, extra_settings, is_project=False):
    emit(f"{config_id} /* {name} */ = {{", 3)
    emit("isa = XCBuildConfiguration;", 4)
    if not is_project:
        emit(f"baseConfigurationReference = {xcconfig_ref_id} /* Supabase.xcconfig */;", 4)
    emit("buildSettings = {", 4)
    if is_project:
        # Project-level settings
        project_settings = {
            "ALWAYS_SEARCH_USER_PATHS": "NO",
            "CLANG_ANALYZER_NONNULL": "YES",
            "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
            "CLANG_ENABLE_MODULES": "YES",
            "CLANG_ENABLE_OBJC_ARC": "YES",
            "COPY_PHASE_STRIP": "NO",
            "ENABLE_STRICT_OBJC_MSGSEND": "YES",
            "GCC_C_LANGUAGE_STANDARD": "gnu17",
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "SDKROOT": "iphoneos",
            "SWIFT_VERSION": "5.0",
        }
        project_settings.update(extra_settings)
        for k, v in sorted(project_settings.items()):
            emit(f"{k} = {v};", 5)
    else:
        all_settings = dict(common_settings)
        all_settings.update(extra_settings)
        for k, v in sorted(all_settings.items()):
            emit(f"{k} = {v};", 5)
    emit("};", 4)
    emit(f'name = {name};', 4)
    emit("};", 3)

emit_build_config(DEBUG_BUILD_CONFIG_ID, "Debug", debug_extra)
emit_build_config(RELEASE_BUILD_CONFIG_ID, "Release", release_extra)
emit_build_config(DEBUG_PROJECT_CONFIG_ID, "Debug", debug_extra, is_project=True)
emit_build_config(RELEASE_PROJECT_CONFIG_ID, "Release", release_extra, is_project=True)

emit("/* End XCBuildConfiguration section */", 2)
emit("")

# XCConfigurationList
emit("/* Begin XCConfigurationList section */", 2)
emit(f"{BUILD_FILES_CONFIG_LIST} /* Build configuration list for PBXNativeTarget EquestrianConnect */ = {{", 3)
emit("isa = XCConfigurationList;", 4)
emit("buildConfigurations = (", 4)
emit(f"{DEBUG_BUILD_CONFIG_ID} /* Debug */,", 5)
emit(f"{RELEASE_BUILD_CONFIG_ID} /* Release */,", 5)
emit(");", 4)
emit('defaultConfigurationIsVisible = 0;', 4)
emit('defaultConfigurationName = Release;', 4)
emit("};", 3)
emit(f"{PROJECT_CONFIG_LIST} /* Build configuration list for PBXProject EquestrianConnect */ = {{", 3)
emit("isa = XCConfigurationList;", 4)
emit("buildConfigurations = (", 4)
emit(f"{DEBUG_PROJECT_CONFIG_ID} /* Debug */,", 5)
emit(f"{RELEASE_PROJECT_CONFIG_ID} /* Release */,", 5)
emit(");", 4)
emit('defaultConfigurationIsVisible = 0;', 4)
emit('defaultConfigurationName = Release;', 4)
emit("};", 3)
emit("/* End XCConfigurationList section */", 2)

emit("};", 1)
emit(f"rootObject = {PROJECT_ID} /* Project object */;", 1)
emit("}")

# Write to disk
os.makedirs(XCODEPROJ, exist_ok=True)
pbxproj_path = os.path.join(XCODEPROJ, "project.pbxproj")
with open(pbxproj_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"✅ Generated: {pbxproj_path}")
print(f"   Sources included: {len(build_files)} .swift files")
print(f"\nNext steps:")
print(f"  1. Open EquestrianConnect.xcodeproj in Xcode")
print(f"  2. Select your Team in Signing & Capabilities")
print(f"  3. Build and run on simulator or device")
