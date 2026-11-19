#!/usr/bin/env python3
"""
generate_xcodeproj.py
Generates a complete, native GyroSteer.xcodeproj without requiring third-party tools.
"""

import os
import sys
import uuid

def generate_id():
    return uuid.uuid4().hex[:24].upper()

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.dirname(script_dir)
    xcodeproj_dir = os.path.join(workspace_root, "GyroSteer.xcodeproj")
    os.makedirs(xcodeproj_dir, exist_ok=True)
    pbxproj_path = os.path.join(xcodeproj_dir, "project.pbxproj")

    # IDs for PBX objects
    proj_id = generate_id()
    main_group_id = generate_id()
    products_group_id = generate_id()
    
    # Target IDs
    mac_target_id = generate_id()
    mac_product_id = generate_id()
    mac_sources_build_phase_id = generate_id()
    mac_frameworks_build_phase_id = generate_id()
    mac_resources_build_phase_id = generate_id()
    
    ios_target_id = generate_id()
    ios_product_id = generate_id()
    ios_sources_build_phase_id = generate_id()
    ios_frameworks_build_phase_id = generate_id()
    ios_resources_build_phase_id = generate_id()

    # Configuration List IDs
    proj_cfg_list_id = generate_id()
    proj_debug_cfg_id = generate_id()
    proj_release_cfg_id = generate_id()

    mac_cfg_list_id = generate_id()
    mac_debug_cfg_id = generate_id()
    mac_release_cfg_id = generate_id()

    ios_cfg_list_id = generate_id()
    ios_debug_cfg_id = generate_id()
    ios_release_cfg_id = generate_id()

    # Collect source files
    shared_files = []
    mac_files = []
    ios_files = []

    for root, dirs, files in os.walk(os.path.join(workspace_root, "Shared")):
        for f in files:
            if f.endswith(".swift"):
                shared_files.append((os.path.relpath(os.path.join(root, f), workspace_root), f))

    for root, dirs, files in os.walk(os.path.join(workspace_root, "GyroSteer-Mac")):
        for f in files:
            if f.endswith(".swift"):
                mac_files.append((os.path.relpath(os.path.join(root, f), workspace_root), f))

    for root, dirs, files in os.walk(os.path.join(workspace_root, "GyroSteer-iOS")):
        for f in files:
            if f.endswith(".swift"):
                ios_files.append((os.path.relpath(os.path.join(root, f), workspace_root), f))

    # Generate FileRefs and BuildFiles
    file_refs = {}
    build_files = {}

    def add_file(rel_path, filename):
        ref_id = generate_id()
        file_refs[ref_id] = (rel_path, filename)
        return ref_id

    def add_build_file(file_ref_id):
        bf_id = generate_id()
        build_files[bf_id] = file_ref_id
        return bf_id

    shared_file_refs = [(add_file(p, f), f) for p, f in shared_files]
    mac_file_refs = [(add_file(p, f), f) for p, f in mac_files]
    ios_file_refs = [(add_file(p, f), f) for p, f in ios_files]

    mac_build_file_ids = [add_build_file(r[0]) for r in shared_file_refs] + [add_build_file(r[0]) for r in mac_file_refs]
    ios_build_file_ids = [add_build_file(r[0]) for r in shared_file_refs] + [add_build_file(r[0]) for r in ios_file_refs]

    # Info.plist and Entitlements refs
    mac_info_ref = add_file("GyroSteer-Mac/Resources/Info.plist", "Info.plist")
    mac_ent_ref = add_file("GyroSteer-Mac/Resources/GyroSteer-Mac.entitlements", "GyroSteer-Mac.entitlements")
    ios_info_ref = add_file("GyroSteer-iOS/Resources/Info.plist", "Info.plist")

    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 56;")
    lines.append("\tobjects = {")

    # PBXBuildFile
    lines.append("/* Begin PBXBuildFile section */")
    for bf_id, ref_id in build_files.items():
        _, fname = file_refs[ref_id]
        lines.append(f"\t\t{bf_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {fname} */; }};")
    lines.append("/* End PBXBuildFile section */")

    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    lines.append(f"\t\t{mac_product_id} /* GyroSteer-Mac.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"GyroSteer-Mac.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};")
    lines.append(f"\t\t{ios_product_id} /* GyroSteer-iOS.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"GyroSteer-iOS.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for ref_id, (rpath, fname) in file_refs.items():
        lines.append(f"\t\t{ref_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{rpath}\"; sourceTree = SOURCE_ROOT; }};")
    lines.append("/* End PBXFileReference section */")

    # PBXFrameworksBuildPhase
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{mac_frameworks_build_phase_id} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    lines.append(f"\t\t{ios_frameworks_build_phase_id} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    lines.append("/* End PBXFrameworksBuildPhase section */")

    # PBXGroup
    lines.append("/* Begin PBXGroup section */")
    all_children_str = ",\n".join([f"\t\t\t\t{ref_id} /* {fname} */" for ref_id, (_, fname) in file_refs.items()])
    lines.append(f"\t\t{main_group_id} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{all_children_str},\n\t\t\t\t{products_group_id} /* Products */\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    lines.append(f"\t\t{products_group_id} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{mac_product_id} /* GyroSteer-Mac.app */,\n\t\t\t\t{ios_product_id} /* GyroSteer-iOS.app */\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    lines.append("/* End PBXGroup section */")

    # PBXNativeTarget
    lines.append("/* Begin PBXNativeTarget section */")
    # Mac Target
    lines.append(f"\t\t{mac_target_id} /* GyroSteer-Mac */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {mac_cfg_list_id} /* Build configuration list for PBXNativeTarget \"GyroSteer-Mac\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{mac_sources_build_phase_id} /* Sources */,")
    lines.append(f"\t\t\t\t{mac_frameworks_build_phase_id} /* Frameworks */,")
    lines.append(f"\t\t\t\t{mac_resources_build_phase_id} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = ();")
    lines.append("\t\t\tdependencies = ();")
    lines.append("\t\t\tname = \"GyroSteer-Mac\";")
    lines.append("\t\t\tproductName = \"GyroSteer-Mac\";")
    lines.append(f"\t\t\tproductReference = {mac_product_id} /* GyroSteer-Mac.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")

    # iOS Target
    lines.append(f"\t\t{ios_target_id} /* GyroSteer-iOS */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {ios_cfg_list_id} /* Build configuration list for PBXNativeTarget \"GyroSteer-iOS\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{ios_sources_build_phase_id} /* Sources */,")
    lines.append(f"\t\t\t\t{ios_frameworks_build_phase_id} /* Frameworks */,")
    lines.append(f"\t\t\t\t{ios_resources_build_phase_id} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = ();")
    lines.append("\t\t\tdependencies = ();")
    lines.append("\t\t\tname = \"GyroSteer-iOS\";")
    lines.append("\t\t\tproductName = \"GyroSteer-iOS\";")
    lines.append(f"\t\t\tproductReference = {ios_product_id} /* GyroSteer-iOS.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")

    # PBXProject
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{proj_id} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1500; };")
    lines.append(f"\t\t\tbuildConfigurationList = {proj_cfg_list_id} /* Build configuration list for PBXProject \"GyroSteer\" */;")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (en, Base);")
    lines.append(f"\t\t\tmainGroup = {main_group_id};")
    lines.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    lines.append("\t\t\tprojectDirPath = \"\";")
    lines.append("\t\t\tprojectRoot = \"\";")
    lines.append("\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{mac_target_id} /* GyroSteer-Mac */,")
    lines.append(f"\t\t\t\t{ios_target_id} /* GyroSteer-iOS */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")

    # PBXResourcesBuildPhase
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{mac_resources_build_phase_id} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    lines.append(f"\t\t{ios_resources_build_phase_id} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    lines.append("/* End PBXResourcesBuildPhase section */")

    # PBXSourcesBuildPhase
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    mac_bfs_str = ",\n".join([f"\t\t\t\t{bf_id} /* in Sources */" for bf_id in mac_build_file_ids])
    lines.append(f"\t\t{mac_sources_build_phase_id} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{mac_bfs_str}\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")

    ios_bfs_str = ",\n".join([f"\t\t\t\t{bf_id} /* in Sources */" for bf_id in ios_build_file_ids])
    lines.append(f"\t\t{ios_sources_build_phase_id} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{ios_bfs_str}\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
    lines.append("/* End PBXSourcesBuildPhase section */")

    # XCBuildConfiguration
    lines.append("/* Begin XCBuildConfiguration section */")
    # Project Debug/Release
    lines.append(f"\t\t{proj_debug_cfg_id} /* Debug */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n\t\t\t\tSWIFT_VERSION = 5.9;\n\t\t\t}};\n\t\t\tname = Debug;\n\t\t}};")
    lines.append(f"\t\t{proj_release_cfg_id} /* Release */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n\t\t\t\tSWIFT_VERSION = 5.9;\n\t\t\t}};\n\t\t\tname = Release;\n\t\t}};")

    # Mac Target Configurations
    mac_settings = """\
				COMBINE_HIDPI_IMAGES = YES;
				SDKROOT = macosx;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.gyrosteer.receiver;
				PRODUCT_NAME = "$(TARGET_NAME)";
				INFOPLIST_FILE = "GyroSteer-Mac/Resources/Info.plist";
				INFOPLIST_EXPAND_BUILD_SETTINGS = YES;
				CODE_SIGN_ENTITLEMENTS = "GyroSteer-Mac/Resources/GyroSteer-Mac.entitlements";
				ENABLE_HARDENED_RUNTIME = YES;
				SWIFT_VERSION = 5.9;
				GENERATE_INFOPLIST_FILE = NO;"""

    lines.append(f"\t\t{mac_debug_cfg_id} /* Debug */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{mac_settings}\n\t\t\t}};\n\t\t\tname = Debug;\n\t\t}};")
    lines.append(f"\t\t{mac_release_cfg_id} /* Release */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{mac_settings}\n\t\t\t}};\n\t\t\tname = Release;\n\t\t}};")

    # iOS Target Configurations
    ios_settings = """\
				SDKROOT = iphoneos;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.gyrosteer.transmitter;
				PRODUCT_NAME = "$(TARGET_NAME)";
				INFOPLIST_FILE = "GyroSteer-iOS/Resources/Info.plist";
				INFOPLIST_EXPAND_BUILD_SETTINGS = YES;
				TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_VERSION = 5.9;
				GENERATE_INFOPLIST_FILE = NO;"""

    lines.append(f"\t\t{ios_debug_cfg_id} /* Debug */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{ios_settings}\n\t\t\t}};\n\t\t\tname = Debug;\n\t\t}};")
    lines.append(f"\t\t{ios_release_cfg_id} /* Release */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{ios_settings}\n\t\t\t}};\n\t\t\tname = Release;\n\t\t}};")
    lines.append("/* End XCBuildConfiguration section */")

    # XCConfigurationList
    lines.append("/* Begin XCConfigurationList section */")
    lines.append(f"\t\t{proj_cfg_list_id} /* Build configuration list for PBXProject \"GyroSteer\" */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{proj_debug_cfg_id} /* Debug */,\n\t\t\t\t{proj_release_cfg_id} /* Release */\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};")
    lines.append(f"\t\t{mac_cfg_list_id} /* Build configuration list for PBXNativeTarget \"GyroSteer-Mac\" */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{mac_debug_cfg_id} /* Debug */,\n\t\t\t\t{mac_release_cfg_id} /* Release */\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};")
    lines.append(f"\t\t{ios_cfg_list_id} /* Build configuration list for PBXNativeTarget \"GyroSteer-iOS\" */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{ios_debug_cfg_id} /* Debug */,\n\t\t\t\t{ios_release_cfg_id} /* Release */\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};")
    lines.append("/* End XCConfigurationList section */")

    lines.append("\t};")
    lines.append(f"\trootObject = {proj_id} /* Project object */;")
    lines.append("}")

    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"✔ Generated Xcode project successfully at: {xcodeproj_dir}")

if __name__ == "__main__":
    main()
