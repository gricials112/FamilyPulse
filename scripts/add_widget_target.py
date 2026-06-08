#!/usr/bin/env python3
"""
Adds the FamilyPulseWidget extension target to the Xcode project.
Run from the ios/ directory:
    python3 ../scripts/add_widget_target.py
"""

import os
import re
import sys
import uuid as _uuid

PROJECT_PATH = "FamilyPulse.xcodeproj/project.pbxproj"
WIDGET_GROUP_PATH = "FamilyPulseWidget"
WIDGET_ENTITLEMENTS = "FamilyPulseWidget/FamilyPulseWidget.entitlements"


def gen_uuid():
    return _uuid.uuid4().hex.upper()[:24]


def read_pbxproj(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write_pbxproj(path, content):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated {path}")


def target_exists(content, target_uuid):
    """Check if the target already exists in the targets array."""
    targets_section = re.search(
        r'targets\s*=\s*\(([^)]*)\);', content, re.DOTALL
    )
    if targets_section:
        return target_uuid in targets_section.group(1)
    return False


def add_widget_target():
    content = read_pbxproj(PROJECT_PATH)

    uuids = {
        "target": gen_uuid(),
        "product": gen_uuid(),
        "group": gen_uuid(),
        "sources": gen_uuid(),
        "frameworks": gen_uuid(),
        "resources": gen_uuid(),
        "configDebug": gen_uuid(),
        "configRelease": gen_uuid(),
        "configList": gen_uuid(),
    }

    if target_exists(content, uuids["target"]):
        print("Widget target already exists, skipping.")
        return

    # ------------------------------------------------------------------
    # 1. PBXFileSystemSynchronizedRootGroup for widget directory
    # ------------------------------------------------------------------
    group_entry = (
        '\n'
        f'\t\t{uuids["group"]} /* {WIDGET_GROUP_PATH} */ = {{\n'
        '\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n'
        f'\t\t\tpath = {WIDGET_GROUP_PATH};\n'
        '\t\t\tsourceTree = "<group>";\n'
        '\t\t};\n'
    )

    insert_after = (
        'CA4961282FCBD2C400888DEC /* FamilyPulseTests */ = {\n'
        '\t\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n'
        '\t\t\t\tpath = FamilyPulseTests;\n'
        '\t\t\t\tsourceTree = "<group>";\n'
        '\t\t\t};'
    )
    content = content.replace(insert_after, insert_after + group_entry)

    # ------------------------------------------------------------------
    # 2. PBXFileReference for widget product
    # ------------------------------------------------------------------
    product_entry = (
        '\n'
        f'\t\t{uuids["product"]} /* FamilyPulseWidgetExtension.appex */ = '
        '{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; '
        'includeInIndex = 0; path = FamilyPulseWidgetExtension.appex; '
        'sourceTree = BUILT_PRODUCTS_DIR; };\n'
    )
    content = content.replace(
        '/* End PBXFileReference section */',
        product_entry + '\t/* End PBXFileReference section */'
    )

    # ------------------------------------------------------------------
    # 3. Add product to Products group
    # ------------------------------------------------------------------
    products_line = '\t\t\t\t\t);\n\t\t\t\tname = Products;'
    products_insert = (
        f'\t\t\t\t\t{uuids["product"]} /* FamilyPulseWidgetExtension.appex */,\n'
    )
    content = content.replace(products_line, products_insert + products_line)

    # ------------------------------------------------------------------
    # 4. Add widget group to main group children
    # ------------------------------------------------------------------
    content = content.replace(
        '\t\t\t\tCA4961282FCBD2C400888DEC /* FamilyPulseTests */,\n',
        (
            '\t\t\t\tCA4961282FCBD2C400888DEC /* FamilyPulseTests */,\n'
            f'\t\t\t\t{uuids["group"]} /* {WIDGET_GROUP_PATH} */,\n'
        ),
    )

    # ------------------------------------------------------------------
    # 5. PBXNativeTarget for the widget
    # ------------------------------------------------------------------
    target_entry = (
        f'\n'
        f'\t\t{uuids["target"]} /* FamilyPulseWidget */ = {{\n'
        '\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = {uuids["configList"]} /* Build configuration list for PBXNativeTarget "FamilyPulseWidget" */;\n'
        '\t\t\tbuildPhases = (\n'
        f'\t\t\t\t{uuids["sources"]} /* Sources */,\n'
        f'\t\t\t\t{uuids["frameworks"]} /* Frameworks */,\n'
        f'\t\t\t\t{uuids["resources"]} /* Resources */,\n'
        '\t\t\t);\n'
        '\t\t\tbuildRules = (\n'
        '\t\t\t);\n'
        '\t\t\tdependencies = (\n'
        '\t\t\t);\n'
        '\t\t\tfileSystemSynchronizedGroups = (\n'
        f'\t\t\t\t{uuids["group"]} /* {WIDGET_GROUP_PATH} */,\n'
        '\t\t\t);\n'
        '\t\t\tname = FamilyPulseWidget;\n'
        '\t\t\tproductName = FamilyPulseWidget;\n'
        f'\t\t\tproductReference = {uuids["product"]};\n'
        '\t\t\tproductType = "com.apple.product-type.app-extension";\n'
        '\t\t};\n'
    )
    content = content.replace(
        '/* End PBXNativeTarget section */',
        target_entry + '\t/* End PBXNativeTarget section */'
    )

    # ------------------------------------------------------------------
    # 6. Add target to project targets array
    # ------------------------------------------------------------------
    content = content.replace(
        '\t\t\t\tCA4961262FCBD2C400888DEC /* FamilyPulseTests */,\n',
        (
            '\t\t\t\tCA4961262FCBD2C400888DEC /* FamilyPulseTests */,\n'
            f'\t\t\t\t{uuids["target"]} /* FamilyPulseWidget */,\n'
        ),
    )

    # ------------------------------------------------------------------
    # 7. Build phases: Sources, Frameworks, Resources
    # ------------------------------------------------------------------
    sources_phase = (
        f'\n'
        f'\t\t{uuids["sources"]} /* Sources */ = {{\n'
        '\t\t\tisa = PBXSourcesBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (\n'
        '\t\t\t);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t}};\n'
    )
    content = content.replace(
        '/* End PBXSourcesBuildPhase section */',
        sources_phase + '\t/* End PBXSourcesBuildPhase section */'
    )

    frameworks_phase = (
        f'\n'
        f'\t\t{uuids["frameworks"]} /* Frameworks */ = {{\n'
        '\t\t\tisa = PBXFrameworksBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (\n'
        '\t\t\t);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t}};\n'
    )
    content = content.replace(
        '/* End PBXFrameworksBuildPhase section */',
        frameworks_phase + '\t/* End PBXFrameworksBuildPhase section */'
    )

    resources_phase = (
        f'\n'
        f'\t\t{uuids["resources"]} /* Resources */ = {{\n'
        '\t\t\tisa = PBXResourcesBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (\n'
        '\t\t\t);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t}};\n'
    )
    content = content.replace(
        '/* End PBXResourcesBuildPhase section */',
        resources_phase + '\t/* End PBXResourcesBuildPhase section */'
    )

    # ------------------------------------------------------------------
    # 8. Build configurations (Debug / Release)
    # ------------------------------------------------------------------
    def _config_block(name):
        return (
            f'\n'
            f'\t\t{uuids["config" + name]} /* {name} */ = {{\n'
            '\t\t\tisa = XCBuildConfiguration;\n'
            '\t\t\tbuildSettings = {\n'
            '\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;\n'
            '\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;\n'
            f'\t\t\t\tCODE_SIGN_ENTITLEMENTS = {WIDGET_ENTITLEMENTS};\n'
            '\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
            '\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
            '\t\t\t\tDEVELOPMENT_TEAM = 96UBFN3CKV;\n'
            '\t\t\t\tENABLE_PREVIEWS = YES;\n'
            '\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n'
            '\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "\\u5bb6\\u5b89\\u5c0f\\u7ec4\\u4ef6";\n'
            '\t\t\t\tINFOPLIST_KEY_CFBundleName = "FamilyPulseWidget";\n'
            '\t\t\t\tINFOPLIST_KEY_CFBundleVersion = "1";\n'
            '\t\t\t\tINFOPLIST_KEY_NSAppIntents = YES;\n'
            '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;\n'
            '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n'
            '\t\t\t\t\t"$(inherited)",\n'
            '\t\t\t\t\t"@executable_path/Frameworks",\n'
            '\t\t\t\t\t"@executable_path/../../Frameworks",\n'
            '\t\t\t\t);\n'
            '\t\t\t\tMARKETING_VERSION = 1.1;\n'
            '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lwj.FamilyPulse.Widget;\n'
            '\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
            '\t\t\t\tSKIP_INSTALL = YES;\n'
            '\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n'
            '\t\t\t\tSWIFT_VERSION = 5.0;\n'
            '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n'
            '\t\t\t};\n'
            f'\t\t\tname = {name};\n'
            '\t\t}};\n'
        )

    debug_block = _config_block("Debug")
    release_block = _config_block("Release")
    content = content.replace(
        '/* End XCBuildConfiguration section */',
        debug_block + release_block + '\t/* End XCBuildConfiguration section */'
    )

    # ------------------------------------------------------------------
    # 9. XCConfigurationList for the widget target
    # ------------------------------------------------------------------
    config_list = (
        f'\n'
        f'\t\t{uuids["configList"]} /* Build configuration list for PBXNativeTarget "FamilyPulseWidget" */ = {{\n'
        '\t\t\tisa = XCConfigurationList;\n'
        '\t\t\tbuildConfigurations = (\n'
        f'\t\t\t\t{uuids["configDebug"]} /* Debug */,\n'
        f'\t\t\t\t{uuids["configRelease"]} /* Release */,\n'
        '\t\t\t);\n'
        '\t\t\tdefaultConfigurationIsVisible = 0;\n'
        '\t\t\tdefaultConfigurationName = Release;\n'
        '\t\t}};\n'
    )
    content = content.replace(
        '/* End XCConfigurationList section */',
        config_list + '\t/* End XCConfigurationList section */'
    )

    # ------------------------------------------------------------------
    # 10. TargetAttributes in PBXProject
    # ------------------------------------------------------------------
    target_attr = (
        f'\n'
        f'\t\t\t\t\t{uuids["target"]} = {{\n'
        '\t\t\t\t\t\tCreatedOnToolsVersion = 26.5;\n'
        '\t\t\t\t\t};'
    )
    content = content.replace(
        '\t\t\t\t\tFA000000000000000000000D = {',
        target_attr + '\n\t\t\t\t\tFA000000000000000000000D = {'
    )

    write_pbxproj(PROJECT_PATH, content)
    print("Widget target 'FamilyPulseWidget' added successfully.")
    print()
    print("Next steps:")
    print("  1. Open FamilyPulse.xcworkspace (or .xcodeproj) in Xcode")
    print("  2. Select the 'FamilyPulseWidget' target")
    print("  3. Go to Signing & Capabilities > Add Capability > App Groups")
    print("     -> Enable 'group.com.lwj.FamilyPulse'")
    print("  4. Do the same for the main 'FamilyPulse' target")
    print("  5. Build and run")


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__) or ".", "../ios"))
    add_widget_target()
