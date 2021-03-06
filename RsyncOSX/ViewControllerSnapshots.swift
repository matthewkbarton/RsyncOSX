//
//  ViewControllerSnapshots.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 22.01.2018.
//  Copyright © 2018 Thomas Evensen. All rights reserved.
//
// swiftlint:disable line_length file_length cyclomatic_complexity type_body_length

import Cocoa
import Foundation

class ViewControllerSnapshots: NSViewController, SetDismisser, SetConfigurations, Delay, Connected, VcMain, Checkforrsync, Setcolor {
    var hiddenID: Int?
    var config: Configuration?
    var snapshotsloggdata: SnapshotsLoggData?
    var delete: Bool = false
    var numbersinsequencetodelete: Int?
    var snapshotstodelete: Double = 0
    var index: Int?
    weak var processterminationDelegate: UpdateProgress?
    var abort: Bool = false
    // Reference to which plan in combox
    var combovalueslast = [NSLocalizedString("none", comment: "plan"),
                           NSLocalizedString("every", comment: "plan"),
                           NSLocalizedString("last", comment: "plan")]

    let combovaluesdayofweek: [String] = [NSLocalizedString("Sunday", comment: "plan"),
                                          NSLocalizedString("Monday", comment: "plan"),
                                          NSLocalizedString("Tuesday", comment: "plan"),
                                          NSLocalizedString("Wednesday", comment: "plan"),
                                          NSLocalizedString("Thursday", comment: "plan"),
                                          NSLocalizedString("Friday", comment: "plan"),
                                          NSLocalizedString("Saturday", comment: "plan")]
    var diddissappear: Bool = false

    @IBOutlet var snapshotstableView: NSTableView!
    @IBOutlet var rsynctableView: NSTableView!
    @IBOutlet var localCatalog: NSTextField!
    @IBOutlet var offsiteCatalog: NSTextField!
    @IBOutlet var offsiteUsername: NSTextField!
    @IBOutlet var backupID: NSTextField!
    @IBOutlet var info: NSTextField!
    @IBOutlet var deletebutton: NSButton!
    @IBOutlet var numberOflogfiles: NSTextField!
    @IBOutlet var deletesnapshots: NSSlider!
    @IBOutlet var stringdeletesnapshotsnum: NSTextField!
    @IBOutlet var gettinglogs: NSProgressIndicator!
    @IBOutlet var deletesnapshotsdays: NSSlider!
    @IBOutlet var stringdeletesnapshotsdaysnum: NSTextField!
    @IBOutlet var selectplan: NSComboBox!
    @IBOutlet var savebutton: NSButton!
    @IBOutlet var selectdayofweek: NSComboBox!
    @IBOutlet var dayofweek: NSTextField!
    @IBOutlet var lastorevery: NSTextField!
    @IBOutlet var profilepopupbutton: NSPopUpButton!

    @IBAction func totinfo(_: NSButton) {
        guard self.checkforrsync() == false else { return }
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerRemoteInfo!)
        }
    }

    @IBAction func quickbackup(_: NSButton) {
        guard self.checkforrsync() == false else { return }
        self.openquickbackup()
    }

    @IBAction func automaticbackup(_: NSButton) {
        self.presentAsSheet(self.viewControllerEstimating!)
    }

    // Selecting profiles
    @IBAction func profiles(_: NSButton) {
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerProfile!)
        }
    }

    // Userconfiguration button
    @IBAction func userconfiguration(_: NSButton) {
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerUserconfiguration!)
        }
    }

    @IBAction func savesnapdayofweek(_: NSButton) {
        var configurations = self.configurations?.getConfigurations()
        guard configurations?.count ?? -1 > 0 else { return }
        if let index = self.index {
            configurations![index].snapdayoffweek = self.config?.snapdayoffweek
            configurations![index].snaplast = self.config?.snaplast
            // Update configuration in memory before saving
            self.configurations?.updateConfigurations(configurations![index], index: index)
        }
    }

    private func initslidersdeletesnapshots() {
        self.deletesnapshots.altIncrementValue = 1.0
        self.deletesnapshots.maxValue = Double(self.snapshotsloggdata?.snapshotslogs?.count ?? 0) - 1.0
        self.deletesnapshots.minValue = 0.0
        self.deletesnapshots.intValue = 0
        self.stringdeletesnapshotsnum.stringValue = "0"
        self.deletesnapshotsdays.altIncrementValue = 1.0
        if let maxdaysold = self.snapshotsloggdata?.snapshotslogs?[0] {
            if let days = maxdaysold.value(forKey: "days") as? String {
                self.deletesnapshotsdays.maxValue = (Double(days) ?? 0.0) + 1
                self.deletesnapshotsdays.intValue = Int32(self.deletesnapshotsdays.maxValue)
                if let maxdaysoldstring = Double(maxdaysold.value(forKey: "days") as? String ?? "100") {
                    self.stringdeletesnapshotsdaysnum.stringValue = String(format: "%.0f", maxdaysoldstring)
                }
            }
        } else {
            self.deletesnapshotsdays.maxValue = 0.0
            self.deletesnapshotsdays.intValue = 0
            self.stringdeletesnapshotsdaysnum.stringValue = "0"
        }
        self.deletesnapshotsdays.minValue = 0.0
        self.numbersinsequencetodelete = 0
    }

    private func initcombox(combobox: NSComboBox, values: [String], index: Int) {
        combobox.removeAllItems()
        combobox.addItems(withObjectValues: values)
        combobox.selectItem(at: index)
    }

    @IBAction func updatedeletesnapshotsnum(_: NSSlider) {
        guard self.index != nil else { return }
        self.stringdeletesnapshotsnum.stringValue = String(self.deletesnapshots.intValue)
        self.numbersinsequencetodelete = Int(self.deletesnapshots.intValue - 1)
        self.markfordelete(numberstomark: self.numbersinsequencetodelete!)
        globalMainQueue.async { () -> Void in
            self.snapshotstableView.reloadData()
        }
        self.info.stringValue = NSLocalizedString("Delete number of snapshots:", comment: "plan") + " " + String(self.deletesnapshots.intValue)
        self.info.textColor = setcolor(nsviewcontroller: self, color: .green)
    }

    @IBAction func updatedeletesnapshotsdays(_: NSSlider) {
        guard self.index != nil else { return }
        self.stringdeletesnapshotsdaysnum.stringValue = String(self.deletesnapshotsdays.intValue)
        self.numbersinsequencetodelete = self.snapshotsloggdata?.countbydays(num: Double(self.deletesnapshotsdays.intValue))
        self.markfordelete(numberstomark: self.numbersinsequencetodelete!)
        globalMainQueue.async { () -> Void in
            self.snapshotstableView.reloadData()
        }
        self.info.stringValue = NSLocalizedString("Delete snapshots older than:", comment: "plan") + " " + String(self.deletesnapshotsdays.intValue)
        self.info.textColor = setcolor(nsviewcontroller: self, color: .green)
    }

    private func markfordelete(numberstomark: Int) {
        for i in 0 ..< (self.snapshotsloggdata?.snapshotslogs?.count ?? 0) - 1 {
            if i <= numberstomark {
                self.snapshotsloggdata?.snapshotslogs![i].setValue(1, forKey: "selectCellID")
            } else {
                self.snapshotsloggdata?.snapshotslogs![i].setValue(0, forKey: "selectCellID")
            }
        }
    }

    // Abort button
    @IBAction func abort(_: NSButton) {
        self.info.stringValue = Infosnapshots().info(num: 2)
        self.snapshotsloggdata?.remotecatalogstodelete = nil
    }

    @IBAction func delete(_: NSButton) {
        guard self.snapshotsloggdata != nil else { return }
        let question: String = NSLocalizedString("Do you REALLY want to DELETE selected snapshots?", comment: "Snapshots")
        let text: String = NSLocalizedString("Cancel or Delete", comment: "Snapshots")
        let dialog: String = NSLocalizedString("Delete", comment: "Snapshots")
        let answer = Alerts.dialogOrCancel(question: question, text: text, dialog: dialog)
        if answer {
            self.info.stringValue = Infosnapshots().info(num: 0)
            self.snapshotsloggdata?.preparecatalogstodelete()
            guard self.snapshotsloggdata?.remotecatalogstodelete != nil else { return }
            self.presentAsSheet(self.viewControllerProgress!)
            self.deletebutton.isEnabled = false
            self.deletesnapshots.isEnabled = false
            self.deletesnapshotcatalogs()
            self.delete = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.snapshotstableView.delegate = self
        self.snapshotstableView.dataSource = self
        self.rsynctableView.delegate = self
        self.rsynctableView.dataSource = self
        self.gettinglogs.usesThreadedAnimation = true
        self.stringdeletesnapshotsnum.delegate = self
        self.stringdeletesnapshotsdaysnum.delegate = self
        self.selectplan.delegate = self
        self.selectdayofweek.delegate = self
        self.savebutton.isEnabled = false
        ViewControllerReference.shared.setvcref(viewcontroller: .vcsnapshot, nsviewcontroller: self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard self.diddissappear == false else { return }
        self.initcombox(combobox: self.selectplan, values: self.combovalueslast, index: 0)
        self.initcombox(combobox: self.selectdayofweek, values: self.combovaluesdayofweek, index: 0)
        self.selectplan.isEnabled = false
        self.selectdayofweek.isEnabled = false
        self.snapshotsloggdata = nil
        self.dayofweek.isHidden = true
        self.lastorevery.isHidden = true
        self.reloadtabledata()
        self.info.textColor = setcolor(nsviewcontroller: self, color: .red)
        self.initpopupbutton(button: self.profilepopupbutton)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.diddissappear = true
    }

    private func deletesnapshotcatalogs() {
        var arguments: SnapshotDeleteCatalogsArguments?
        var deletecommand: SnapshotCommandDeleteCatalogs?
        guard self.snapshotsloggdata?.remotecatalogstodelete != nil else {
            self.deletebutton.isEnabled = true
            self.deletesnapshots.isEnabled = true
            self.info.stringValue = Infosnapshots().info(num: 0)
            return
        }
        guard (self.snapshotsloggdata?.remotecatalogstodelete?.count ?? -1) > 0 else {
            self.deletebutton.isEnabled = true
            self.deletesnapshots.isEnabled = true
            self.info.stringValue = Infosnapshots().info(num: 0)
            return
        }
        let remotecatalog = self.snapshotsloggdata!.remotecatalogstodelete![0]
        self.snapshotsloggdata!.remotecatalogstodelete!.remove(at: 0)
        if self.snapshotsloggdata!.remotecatalogstodelete!.count == 0 {
            self.snapshotsloggdata!.remotecatalogstodelete = nil
        }
        if let config = self.config {
            arguments = SnapshotDeleteCatalogsArguments(config: config, remotecatalog: remotecatalog)
            deletecommand = SnapshotCommandDeleteCatalogs(command: arguments?.getCommand(), arguments: arguments?.getArguments())
            deletecommand?.setdelegate(object: self)
            deletecommand?.executeProcess(outputprocess: nil)
        }
    }

    // setting which table row is selected
    func tableViewSelectionDidChange(_ notification: Notification) {
        let myTableViewFromNotification = (notification.object as? NSTableView)!
        if myTableViewFromNotification == self.snapshotstableView {
            let indexes = myTableViewFromNotification.selectedRowIndexes
            if let index = indexes.first {
                if let dict = self.snapshotsloggdata?.snapshotslogs?[index] {
                    self.hiddenID = dict.value(forKey: "hiddenID") as? Int
                    guard self.hiddenID != nil else { return }
                    self.index = self.configurations?.getIndex(hiddenID!)
                }
            } else {
                self.index = nil
            }
        } else {
            let indexes = myTableViewFromNotification.selectedRowIndexes
            if let index = indexes.first {
                if let config = self.configurations?.getConfigurations()[index] {
                    guard self.connected(config: config) == true else {
                        self.info.stringValue = Infosnapshots().info(num: 6)
                        return
                    }
                    self.selectplan.isEnabled = false
                    self.selectdayofweek.isEnabled = false
                    self.info.stringValue = Infosnapshots().info(num: 0)
                    let hiddenID = self.configurations?.getConfigurationsDataSourceSynchronize()?[index].value(forKey: "hiddenID") as? Int ?? -1
                    self.index = self.configurations?.getIndex(hiddenID)
                    self.getsourcebyindex(index: hiddenID)
                }
            } else {
                self.selectplan.isEnabled = false
                self.selectdayofweek.isEnabled = false
                self.snapshotsloggdata = nil
                self.index = nil
                self.localCatalog.stringValue = ""
                self.offsiteCatalog.stringValue = ""
                self.offsiteUsername.stringValue = ""
                self.backupID.stringValue = ""
                self.info.stringValue = ""
                self.reloadtabledata()
            }
        }
    }

    func getsourcebyindex(index: Int) {
        self.hiddenID = index
        self.config = self.configurations?.getConfigurations()[self.configurations?.getIndex(index) ?? -1]
        guard self.config?.task == ViewControllerReference.shared.snapshot else {
            self.info.stringValue = Infosnapshots().info(num: 1)
            self.index = nil
            return
        }
        if let config = self.config {
            self.snapshotsloggdata = SnapshotsLoggData(config: config, getsnapshots: true)
            self.localCatalog.stringValue = config.localCatalog
            self.offsiteCatalog.stringValue = config.offsiteCatalog
            self.offsiteUsername.stringValue = config.offsiteUsername
            self.backupID.stringValue = config.backupID
            self.info.stringValue = Infosnapshots().info(num: 0)
            self.gettinglogs.startAnimation(nil)
        }
    }

    private func preselectcomboboxes() {
        self.selectdayofweek.selectItem(withObjectValue: NSLocalizedString(self.config?.snapdayoffweek ?? "Sunday", comment: "dayofweek"))
        if self.config?.snaplast ?? 1 == 1 {
            self.selectplan.selectItem(withObjectValue: NSLocalizedString("every", comment: "plan"))
        } else {
            self.selectplan.selectItem(withObjectValue: NSLocalizedString("last", comment: "plan"))
        }
    }

    private func setlabeldayofweekandlast() {
        self.dayofweek.textColor = self.setcolor(nsviewcontroller: self, color: .green)
        self.lastorevery.textColor = self.setcolor(nsviewcontroller: self, color: .green)
        self.dayofweek.isHidden = false
        self.lastorevery.isHidden = false
        self.dayofweek.stringValue = NSLocalizedString(self.config?.snapdayoffweek ?? "Sunday", comment: "dayofweek")
        if self.config?.snaplast ?? 1 == 1 {
            self.lastorevery.stringValue = NSLocalizedString("every", comment: "plan")
        } else {
            self.lastorevery.stringValue = NSLocalizedString("last", comment: "plan")
        }
    }

    private func initpopupbutton(button: NSPopUpButton) {
        var profilestrings: [String]?
        profilestrings = CatalogProfile().getDirectorysStrings()
        profilestrings?.insert(NSLocalizedString("Default profile", comment: "default profile"), at: 0)
        button.removeAllItems()
        button.addItems(withTitles: profilestrings ?? [])
        button.selectItem(at: 0)
    }

    @IBAction func selectprofile(_: NSButton) {
        var profile = self.profilepopupbutton.titleOfSelectedItem
        if profile == NSLocalizedString("Default profile", comment: "default profile") {
            profile = nil
        }
        _ = Selectprofile(profile: profile)
    }
}

extension ViewControllerSnapshots: DismissViewController {
    func dismiss_view(viewcontroller: NSViewController) {
        self.dismiss(viewcontroller)
        if self.snapshotsloggdata?.remotecatalogstodelete != nil {
            self.snapshotsloggdata?.remotecatalogstodelete = nil
            self.info.stringValue = Infosnapshots().info(num: 2)
            self.abort = true
        }
    }
}

extension ViewControllerSnapshots: UpdateProgress {
    func processTermination() {
        self.selectplan.isEnabled = true
        self.selectdayofweek.isEnabled = true
        if delete {
            if let vc = ViewControllerReference.shared.getvcref(viewcontroller: .vcprogressview) as? ViewControllerProgressProcess {
                if self.snapshotsloggdata!.remotecatalogstodelete == nil {
                    self.delete = false
                    self.deletebutton.isEnabled = true
                    self.deletesnapshots.isEnabled = true
                    self.info.stringValue = Infosnapshots().info(num: 3)
                    self.snapshotsloggdata = SnapshotsLoggData(config: self.config!, getsnapshots: true)
                    if self.abort == true {
                        self.abort = false
                    } else {
                        vc.processTermination()
                    }
                } else {
                    vc.fileHandler()
                }
                self.deletesnapshotcatalogs()
            }
        } else {
            self.deletebutton.isEnabled = true
            self.snapshotsloggdata?.processTermination()
            self.initslidersdeletesnapshots()
            self.gettinglogs.stopAnimation(nil)
            self.numbersinsequencetodelete = nil
            self.preselectcomboboxes()
            _ = PlanSnapshots(plan: self.config?.snaplast ?? 1, snapdayoffweek: self.config?.snapdayoffweek ?? StringDayofweek.Sunday.rawValue)
            globalMainQueue.async { () -> Void in
                self.snapshotstableView.reloadData()
            }
        }
    }

    func fileHandler() {
        //
    }
}

extension ViewControllerSnapshots: Count {
    func maxCount() -> Int {
        let max = self.snapshotsloggdata?.remotecatalogstodelete?.count ?? 0
        self.snapshotstodelete = Double(max)
        return max
    }

    func inprogressCount() -> Int {
        let progress = Int(self.snapshotstodelete) - (self.snapshotsloggdata?.remotecatalogstodelete?.count ?? 0)
        return progress
    }
}

extension ViewControllerSnapshots: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.snapshotstableView {
            let numberofsnaps: String = NSLocalizedString("Number snapshots:", comment: "Snapshots")
            guard self.snapshotsloggdata?.snapshotslogs != nil else {
                self.numberOflogfiles.stringValue = numberofsnaps + " "
                return 0
            }
            self.numberOflogfiles.stringValue = numberofsnaps + " " + String(self.snapshotsloggdata?.snapshotslogs?.count ?? 0)
            return self.snapshotsloggdata?.snapshotslogs?.count ?? 0
        } else {
            return self.configurations?.getConfigurationsDataSourceSynchronize()?.count ?? 0
        }
    }
}

extension ViewControllerSnapshots: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView == self.rsynctableView {
            guard row < self.configurations!.getConfigurationsDataSourceSynchronize()!.count else { return nil }
            guard row < self.configurations!.getConfigurationsDataSourceSynchronize()!.count else { return nil }
            let object: NSDictionary = self.configurations!.getConfigurationsDataSourceSynchronize()![row]
            return object[tableColumn!.identifier] as? String
        } else {
            guard row < self.snapshotsloggdata?.snapshotslogs!.count ?? 0 else { return nil }
            let object: NSDictionary = self.snapshotsloggdata!.snapshotslogs![row]
            if tableColumn!.identifier.rawValue == "selectCellID" {
                return object[tableColumn!.identifier] as? Int
            } else {
                return object[tableColumn!.identifier] as? String
            }
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue _: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard tableView == self.snapshotstableView else { return }
        if tableColumn!.identifier.rawValue == "selectCellID" {
            var select: Int = (self.snapshotsloggdata?.snapshotslogs![row].value(forKey: "selectCellID") as? Int) ?? 0
            if select == 0 { select = 1 } else if select == 1 { select = 0 }
            guard row < self.snapshotsloggdata!.snapshotslogs!.count - 1 else { return }
            self.snapshotsloggdata?.snapshotslogs![row].setValue(select, forKey: "selectCellID")
        }
    }
}

extension ViewControllerSnapshots: Reloadandrefresh {
    func reloadtabledata() {
        self.setlabeldayofweekandlast()
        globalMainQueue.async { () -> Void in
            self.snapshotstableView.reloadData()
            self.rsynctableView.reloadData()
        }
    }
}

extension ViewControllerSnapshots: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        self.delayWithSeconds(0.5) {
            guard self.snapshotsloggdata != nil else { return }
            if (notification.object as? NSTextField)! == self.stringdeletesnapshotsnum {
                if self.stringdeletesnapshotsnum.stringValue.isEmpty == false {
                    if let num = Int(self.stringdeletesnapshotsnum.stringValue) {
                        self.info.stringValue = Infosnapshots().info(num: 0)
                        if num > self.snapshotsloggdata?.snapshotslogs?.count ?? 0 {
                            self.deletesnapshots.intValue = Int32((self.snapshotsloggdata?.snapshotslogs?.count)! - 1)
                            self.info.stringValue = Infosnapshots().info(num: 5)
                        } else {
                            self.deletesnapshots.intValue = Int32(num)
                        }
                        self.numbersinsequencetodelete = Int(self.deletesnapshots.intValue) - 1
                        self.markfordelete(numberstomark: self.numbersinsequencetodelete!)
                        globalMainQueue.async { () -> Void in
                            self.snapshotstableView.reloadData()
                        }
                    } else {
                        self.info.stringValue = Infosnapshots().info(num: 4)
                    }
                }
            } else {
                if self.stringdeletesnapshotsdaysnum.stringValue.isEmpty == false {
                    if let num = Int(self.stringdeletesnapshotsdaysnum.stringValue) {
                        self.deletesnapshotsdays.intValue = Int32(num)
                        self.numbersinsequencetodelete = self.snapshotsloggdata!.countbydays(num: Double(self.stringdeletesnapshotsdaysnum.stringValue) ?? 0)
                        self.markfordelete(numberstomark: self.numbersinsequencetodelete!)
                        globalMainQueue.async { () -> Void in
                            self.snapshotstableView.reloadData()
                        }
                    } else {
                        self.info.stringValue = Infosnapshots().info(num: 4)
                    }
                }
            }
        }
    }
}

extension ViewControllerSnapshots: GetSnapshotsLoggData {
    func getsnapshotsloggdata() -> SnapshotsLoggData? {
        return self.snapshotsloggdata
    }
}

extension ViewControllerSnapshots: NewProfile {
    func newProfile(profile _: String?) {
        self.snapshotsloggdata = nil
        globalMainQueue.async { () -> Void in
            self.snapshotstableView.reloadData()
        }
        self.localCatalog.stringValue = ""
        self.offsiteCatalog.stringValue = ""
        self.offsiteUsername.stringValue = ""
        self.backupID.stringValue = ""
    }

    func enableselectprofile() {
        //
    }
}

extension ViewControllerSnapshots: NSComboBoxDelegate {
    func comboBoxSelectionDidChange(_: Notification) {
        guard self.config != nil else { return }
        self.savebutton.isEnabled = true
        switch self.selectdayofweek.indexOfSelectedItem {
        case 0:
            self.config!.snapdayoffweek = StringDayofweek.Sunday.rawValue
        case 1:
            self.config!.snapdayoffweek = StringDayofweek.Monday.rawValue
        case 2:
            self.config!.snapdayoffweek = StringDayofweek.Tuesday.rawValue
        case 3:
            self.config!.snapdayoffweek = StringDayofweek.Wednesday.rawValue
        case 4:
            self.config!.snapdayoffweek = StringDayofweek.Thursday.rawValue
        case 5:
            self.config!.snapdayoffweek = StringDayofweek.Friday.rawValue
        case 6:
            self.config!.snapdayoffweek = StringDayofweek.Saturday.rawValue
        default:
            self.config!.snapdayoffweek = StringDayofweek.Sunday.rawValue
        }
        self.info.stringValue = ""
        switch self.selectplan.indexOfSelectedItem {
        case 1:
            self.config!.snaplast = 1
            _ = PlanSnapshots(plan: 1, snapdayoffweek: self.config?.snapdayoffweek ?? StringDayofweek.Sunday.rawValue)
        case 2:
            self.config!.snaplast = 2
            _ = PlanSnapshots(plan: 2, snapdayoffweek: self.config?.snapdayoffweek ?? StringDayofweek.Sunday.rawValue)
        default:
            return
        }
    }
}

extension ViewControllerSnapshots: OpenQuickBackup {
    func openquickbackup() {
        globalMainQueue.async { () -> Void in
            self.presentAsSheet(self.viewControllerQuickBackup!)
        }
    }
}

extension ViewControllerSnapshots: GetSelecetedIndex {
    func getindex() -> Int? {
        return self.index
    }
}
