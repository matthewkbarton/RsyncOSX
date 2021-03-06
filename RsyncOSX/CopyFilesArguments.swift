//
//  scpNSTaskArguments.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 27/06/16.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable line_length

import Foundation

enum Enumscopyfiles {
    case rsync
    case rsyncfilelistings
    case snapshotcatalogs
}

final class CopyFilesArguments: ProcessArguments {
    private var arguments: [String]?
    private var argdisplay: String?
    private var command: String?
    private var config: Configuration?

    func getArguments() -> [String]? {
        return self.arguments
    }

    func getCommand() -> String? {
        return self.command
    }

    func getcommandDisplay() -> String {
        guard self.argdisplay != nil else { return "" }
        return self.argdisplay!
    }

    init(task: Enumscopyfiles, config: Configuration, remoteFile: String?, localCatalog: String?, drynrun: Bool?) {
        self.arguments = [String]()
        self.config = config
        switch task {
        case .rsync:
            let arguments = RsyncParametersSingleFilesArguments(config: config, remoteFile: remoteFile, localCatalog: localCatalog, drynrun: drynrun)
            self.arguments = arguments.getArguments()
            self.command = arguments.getCommand()
            self.argdisplay = arguments.getArgumentsDisplay()
        case .rsyncfilelistings:
            let arguments = GetRemoteFileListingsArguments(config: config, recursive: true)
            self.arguments = arguments.getArguments()
            self.command = arguments.getCommand()
        case .snapshotcatalogs:
            let arguments = GetRemoteFileListingsArguments(config: config, recursive: false)
            self.arguments = arguments.getArguments()
            self.command = arguments.getCommand()
        }
    }
}
