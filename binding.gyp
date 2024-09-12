{
    "targets": [
        {
            "target_name": "efphelper",
            "cflags!": ["-fno-exceptions"],
            "cflags_cc!": ["-fno-exceptions"],
            "sources": ["src/efphelper.mm"],
            "dependencies": [
                "<!(node -p \"require('node-addon-api').targets\"):node_addon_api",
            ],
            "conditions": [
                [
                    'OS=="mac"',
                    {
                        "cflags+": ["-fvisibility=hidden"],
                        "sources": ["src/efphelper.mm"],
                        "xcode_settings": {
                            # "ARCHS": ["x86_64", "arm64"],
                            "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
                            "CLANG_CXX_LIBRARY": "libc++",
                            "MACOSX_DEPLOYMENT_TARGET": "11.0",
                            "GCC_SYMBOLS_PRIVATE_EXTERN": "YES",  # -fvisibility=hidden
                            "OTHER_CFLAGS": ["-fobjc-arc"],
                        },
                    },
                ]
            ],
        }
    ]
}
