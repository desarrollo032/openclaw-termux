import json, os

content = r'''{
	"version": "0.2.0",
	"configurations": [
		// ═══════════════════════════════════════════
		//  📱 FLUTTER APP
		// ═══════════════════════════════════════════

		{
			"name": "🔵 Flutter - Debug",
			"type": "dart",
			"request": "launch",
			"program": "flutter_app/lib/main.dart",
			"args": [],
			"flutterMode": "debug",
			"flutterTrackWidgetCreation": true,
			"preLaunchTask": "📱 Flutter - Analyze"
		},
		{
			"name": "🟢 Flutter - Profile",
			"type": "dart",
			"request": "launch",
			"program": "flutter_app/lib/main.dart",
			"args": [],
			"flutterMode": "profile",
			"flutterTrackWidgetCreation": false
		},
		{
			"name": "🔴 Flutter - Release",
			"type": "dart",
			"request": "launch",
			"program": "flutter_app/lib/main.dart",
			"args": [],
			"flutterMode": "release",
			"flutterTrackWidgetCreation": false
		},

		// ═══════════════════════════════════════════
		//  🌐 FLUTTER — WEB
		// ═══════════════════════════════════════════

		{
			"name": "🌐 Flutter - Web (Chrome)",
			"type": "dart",
			"request": "launch",
			"program": "flutter_app/lib/main.dart",
			"args": ["-d", "chrome"],
			"flutterMode": "debug",
			"flutterTrackWidgetCreation": true
		},

		// ═══════════════════════════════════════════
		//  📦 NODE.JS CLI
		// ═══════════════════════════════════════════

		{
			"name": "🔶 Node CLI - Setup",
			"type": "node",
			"request": "launch",
			"program": "lib/index.js",
			"args": ["setup"],
			"cwd": "${workspaceFolder}",
			"console": "integratedTerminal",
			"env": {
				"NODE_ENV": "development",
				"DEBUG": "openclaw:*"
			}
		},
		{
			"name": "🔶 Node CLI - Start",
			"type": "node",
			"request": "launch",
			"program": "lib/index.js",
			"args": ["start"],
			"cwd": "${workspaceFolder}",
			"console": "integratedTerminal",
			"env": {
				"NODE_ENV": "production"
			}
		},
		{
			"name": "🔶 Node CLI - Shell",
			"type": "node",
			"request": "launch",
			"program": "lib/index.js",
			"args": ["shell"],
			"cwd": "${workspaceFolder}",
			"console": "integratedTerminal",
			"env": {
				"NODE_ENV": "development"
			}
		},
		{
			"name": "🔶 Node CLI - Doctor",
			"type": "node",
			"request": "launch",
			"program": "lib/index.js",
			"args": ["doctor"],
			"cwd": "${workspaceFolder}",
			"console": "integratedTerminal"
		},

		// ═══════════════════════════════════════════
		//  🧪 NODE.JS — TESTS
		// ═══════════════════════════════════════════

		{
			"name": "🧪 Node - Tests",
			"type": "node",
			"request": "launch",
			"program": "lib/test.js",
			"cwd": "${workspaceFolder}",
			"console": "integratedTerminal",
			"env": {
				"NODE_ENV": "test"
			}
		},

		// ═══════════════════════════════════════════
		//  🔗 ATTACH TO RUNNING PROCESSES
		// ═══════════════════════════════════════════

		{
			"name": "🔗 Attach to Flutter",
			"type": "dart",
			"request": "attach"
		},
		{
			"name": "🔗 Attach to Node Process",
			"type": "node",
			"request": "attach",
			"port": 9229,
			"restart": true,
			"localRoot": "${workspaceFolder}",
			"remoteRoot": "${workspaceFolder}"
		}
	],

	// ═══════════════════════════════════════════
	//  🔄 COMPOUND LAUNCH CONFIGS
	// ═══════════════════════════════════════════

	"compounds": [
		{
			"name": "🔄 Full Dev - Flutter + CLI",
			"configurations": ["🔵 Flutter - Debug", "🔶 Node CLI - Start"],
			"preLaunchTask": "📱 Flutter - Get Dependencies"
		}
	]
}
'''

target = os.path.join('.vscode', 'launch.json')
with open(target, 'w', encoding='utf-8') as f:
    f.write(content)
print(f'Written {len(content)} bytes to {target}')
