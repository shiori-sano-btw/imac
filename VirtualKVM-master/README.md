VirtualKVM
==========

Useful for those who use their iMac as a monitor for their Macbook.

Automatically toggles off your iMac's Bluetooth and turns on Target Display Mode when you connect a Macbook via Thunderbolt.

To use, simply run. Might want to run at startup. When you plug your notebook into your iMac via Thunderbolt,
this extension will automatically switch the iMac to Target Display Mode, allowing you to use your iMac as a monitor.

In addition, it will turn off the Bluetooth on the iMac, freeing up your mouse and keyboard to pair with your notebook.
When you unplug the notebook, the iMac's Bluetooth will be powered back up and the monitor restored.

If you install it on your Macbook, the opposite happens. When you connect to the iMac the Macbook's Bluetooth will turn on, and then off again when you disconnect.

Quit and control options from the status bar menu.

Installing
===========

You can download the latest [release build](https://github.com/duanefields/VirtualKVM/releases) from the release tab, or you build it yourself.

Building
========
This project requires CocoaPods.

 * sudo gem install cocoapods
 * pod install

Open VirtualKVM.xcworkspace in Xcode and build...

Known Issues
============

* Bluetooth switching between newer Apple wireless (keyboards, mice, trackpads) is unsupported.

* When bluetooth is disabled, if the macbook goes to sleep, the iMac failes to re-instate target display mode, I THINK because it no longer has a keyboard and thus I can't send keyboard command sequences, which is the only way I know how to trigger
target display mode. Let me know if you have any ideas.
