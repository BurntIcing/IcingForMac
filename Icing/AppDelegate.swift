//
//  AppDelegate.swift
//  BurntIcing
//
//  Created by Patrick Smith on 14/02/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



	func applicationDidFinishLaunching(aNotification: NSNotification) {
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}
	
	
	@IBAction func openIcingEditorOnGitHub(sender: AnyObject) {
		IcingOpenSourceProject.IcingEditor.openURL()
	}
	
	@IBAction func openIcingSpecsOnGitHub(sender: AnyObject) {
		IcingOpenSourceProject.Specs.openURL()
	}
	
	@IBAction func openIcingPHPLibraryOnGitHub(sender: AnyObject) {
		IcingOpenSourceProject.IcingPHP.openURL()
	}
}

