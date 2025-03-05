#!/bin/bash

# CAUTION: Using a "here document" as a comment block, just for convenience.
: <<'COMMENTBLOCK'
{file:
	{name: VidyoConnectorVersion_.sh}
	{description: Defines version numbers for the VidyoConnector App for iOS,
		later released as the "Vidyo.io Connector" on the iOS App Store.
		Invoke this during a custom "Run Script" build phase in Xcode after the
		target Property List file is generated, but before it is code-signed.
	}
	{copyright:
		(c) 2022 Vidyo, Inc.,
		433 Hackensack Avenue, 7th Floor,
		Hackensack, NJ  07601.

		All rights reserved.

		The information contained herein is proprietary to Vidyo, Inc.
		and shall not be reproduced, copied (in whole or in part), adapted,
		modified, disseminated, transmitted, transcribed, stored in a retrieval
		system, or translated into any language in any form by any means
		without the express written consent of Vidyo, Inc.
		                  ***** CONFIDENTIAL *****
	}
}
COMMENTBLOCK

# NOTE: Build tools/scripts automatically rewrite lines below to update version.
VIDYO_XCODE_CFBundleShortVersionString="24.1.2"
VIDYO_XCODE_CFBundleVersion="1"

# Modify relevant values in the build-generated Property List.
# - Update what Apple calls the "version number" and the "build number".
# - See Apple's "Technical Note TN2420: Version Numbers and Build Numbers"
#   at <https://developer.apple.com/library/content/technotes/tn2420/>.
/usr/libexec/PlistBuddy -c \
	"Set :CFBundleShortVersionString ${VIDYO_XCODE_CFBundleShortVersionString}" \
	"${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
/usr/libexec/PlistBuddy -c \
	"Set :CFBundleVersion ${VIDYO_XCODE_CFBundleVersion}" \
	"${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

# NOTE: A freely-available version-numbering helper for Xcode was REJECTED:
# - See Apple's "Technical Q&A QA1827: Automating Version and Build Numbers
#   Using agvtool" at <https://developer.apple.com/library/content/qa/qa1827/>.
# - 'agvtool' is limited (or strongly tied) to macOS. / Our scheme allows for
#   version-numbering updates under any OS where this file can be modified.
# - 'agvtool' can integrate with a few version-control systems (but the feature
#   seems like an unnecessary entanglement). / Our scheme is not tied to any
#   version-control system, so it should be compatible with any of them.
