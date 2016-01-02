//
//  MeetingsViewController.swift
//  YACA
//
//  Created by Andreas Pfister on 13/12/15.
//  Copyright © 2015 Andy P. All rights reserved.
//

import Foundation
import UIKit
import EventKit
import Contacts
import CoreData


class MeetingsViewController: UIViewController {
    
    var backgroundGradient: CAGradientLayer? = nil
    var meeting: Meeting!
    var events = [EKEvent]()
    let eventStore = EKEventStore()
    var calendars: [EKCalendar]?
    var selectedCalendar: String?
    var duration: Int = 0
    var eventSource: Datasource?
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var tapRecognizer: UITapGestureRecognizer? = nil
    @IBOutlet weak var meetingCollectionView: UICollectionView!
    @IBOutlet weak var calendarName: UILabel!
    @IBOutlet weak var durationSgements: CustomSegmentedControl!
    @IBOutlet weak var loadIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.meetingCollectionView?.registerNib(UINib(nibName: "MeetingListCellHeader", bundle: nil), forSupplementaryViewOfKind:UICollectionElementKindSectionHeader, withReuseIdentifier: "meetingCellHeader")
        tapRecognizer = UITapGestureRecognizer(target: self, action: "handleSingleTap:")
        tapRecognizer?.numberOfTapsRequired = 1
        tapRecognizer?.cancelsTouchesInView = false
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        configureUI()
        addKeyboardDismissRecognizer()
        
        // MARK: - Load Events from selected Calendar
        if (NSUserDefaults.standardUserDefaults().stringForKey("selectedCalendar") != nil) {
            self.selectedCalendar = NSUserDefaults.standardUserDefaults().stringForKey("selectedCalendar")
            calendarName.text = self.eventStore.calendarWithIdentifier(self.selectedCalendar!)?.title
        } else {
            self.tabBarController?.selectedIndex = 2
            return
        }
        // MARK: - Adjust custom control and set duration
        durationSgements.items = ["1 day", "1 week", "1 month"]
        durationSgements.font = UIFont(name: "Roboto-Regular", size: 12)
        durationSgements.borderColor = UIColor(white: 1.0, alpha: 0.3)
        durationSgements.addTarget(self, action: "changeDuration:", forControlEvents: .ValueChanged)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "iCloudUpdated:", name: "kRefetchDatabaseNotification", object: nil)
        
        self.duration = getDurationOfIndex(NSUserDefaults.standardUserDefaults().integerForKey("durationIndex"))
        loadIndicator.startAnimating()
        
        self.loadEvents() { success in
            if success {
                self.loadIndicator.stopAnimating()
                self.meetingCollectionView.hidden = false
                self.meetingCollectionView.reloadData()
            }
        }
        
        //weatherTest.text = OWFontIcons["802"]
        //weatherTest.font = UIFont.fontOWOfSize(100)
        //weatherTest.text = String.fontAwesomeIconWithCode("803")
        //print(weatherTest.text?.unicodeScalars)
    }
    
    // MARK: - There was something updated in iCloud and this new information got received, updating the meetings !
    func iCloudUpdated (notification: NSNotification) {
        print("        CoreData UPDATED, reloading collectionView")
        meetingCollectionView.reloadData()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        // MARK: - Apply value to segmented control after view is visible, otherwise uiview.animate is not working
        durationSgements.selectedIndex = NSUserDefaults.standardUserDefaults().integerForKey("durationIndex")
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        removeKeyboardDismissRecognizer()
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "kRefetchDatabaseNotification",object: nil )
    }
    
    // MARK: - Returns seconds for 1 day (index=0), 1 week (index=1) and 1 month (index=2)
    func getDurationOfIndex(index: Int) -> Int {
        var duration = 0
        switch index {
        case 0:
            duration = 86400
        case 1:
            duration = 604800
        case 2:
            duration = 2419200
        default:
            duration = 0
        }
        return duration
    }
    
    func changeDuration(sender: AnyObject?) {
        let localDuration = getDurationOfIndex(durationSgements.selectedIndex)
        NSUserDefaults.standardUserDefaults().setValue(durationSgements.selectedIndex, forKey: "durationIndex")
        NSUserDefaults.standardUserDefaults().setValue(localDuration, forKey: "duration")
        self.duration = localDuration
        loadIndicator.startAnimating()
        
        self.loadEvents() { success in
            if success {
                self.loadIndicator.stopAnimating()
                self.meetingCollectionView.hidden = false
                self.meetingCollectionView.reloadData()
            } else {
                // no access to calendar !!
            }
        }
        
        /*
        appDelegate.backgroundThread(0.0, background: {
            
            }, completion: {
                
        })
        */
    }
    
    // MARK: - Core Data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: Meeting.statics.entityName)
        fetchRequest.predicate = NSPredicate(format: "meeting == %@", self.meeting)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Meeting.Keys.Name, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
}

// MARK: - CollectionView related methods
extension MeetingsViewController: UICollectionViewDataSource {
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        if eventSource != nil {
            return (eventSource?.daysOfMeeting.count)!
        }
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        //something to do when clicked --- NOPE, we are having all interactions within the Cell itself
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        
        let headerCell = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: "meetingCellHeader", forIndexPath: indexPath) as? MeetingListCellHeader

        headerCell?.dayLabel.text = eventSource?.getSpecialWeekdayOfDate((eventSource?.sortedMeetingArray[indexPath.section])!)
        
        return headerCell!
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        if let currentDate = eventSource?.sortedMeetingArray[section] {
            if let currentDateObjects = eventSource?.daysOfMeeting[currentDate] {
                return currentDateObjects.count
            }
        }
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("meetingViewCell", forIndexPath: indexPath) as! MeetingListCell
        if let currentDate = eventSource?.sortedMeetingArray[indexPath.section] {
            if let currentDateObjects = eventSource?.daysOfMeeting[currentDate] {
                if let meetingObject = currentDateObjects[indexPath.row] as? Meeting {
                    cell.calendarName.text = meetingObject.name
                    cell.timingLabel?.text = (eventSource?.getTimeOfDate(meetingObject.starttime))! + " - " + (eventSource?.getTimeOfDate(meetingObject.endtime))!
                    cell.cellIdentifier = "meetingParticipant_" + String(indexPath.row)
                    cell.meeting = meetingObject
                    cell.participantDetails.hidden = true
                    cell.participantTable.reloadData()
                    cell.configureUI()
                    if let meetingNote = meetingObject.note {
                        cell.notesText.text = meetingNote.note
                    } else {
                        cell.notesText.text = ""
                    }
                }
            }
        }
        return cell
    }
}

// MARK: - Customize UI

extension MeetingsViewController {
    
    func configureUI() {
        /* Configure background gradient */
        self.view.backgroundColor = UIColor.clearColor()
        //let colorTop = UIColor(red: 0.345, green: 0.839, blue: 0.988, alpha: 1.0).CGColor
        let colorTop = UIColor(red: 1, green: 0.680, blue: 0.225, alpha: 1.0).CGColor
        //let colorBottom = UIColor(red: 0.023, green: 0.569, blue: 0.910, alpha: 1.0).CGColor
        let colorBottom = UIColor(red: 1, green: 0.594, blue: 0.128, alpha: 1.0).CGColor
        self.backgroundGradient = CAGradientLayer()
        self.backgroundGradient!.colors = [colorTop, colorBottom]
        self.backgroundGradient!.locations = [0.0, 1.0]
        self.backgroundGradient!.frame = view.frame
        self.view.layer.insertSublayer(self.backgroundGradient!, atIndex: 0)
    }
    
}

// MARK: - Calendar background actions (will/should be called in a backgroundThread)
extension MeetingsViewController {
    
    func loadEvents(completionHandler: (result: Bool) -> Void) {
        appDelegate.checkCalendarAuthorizationStatus { (accessGranted) -> Void in
            if accessGranted {
                self.fetchEvents(self.eventStore, calendarIdentity: self.selectedCalendar!, completed: { (events: [EKEvent]) -> Void in
                    // We are going to empty the events array first
                    self.events = [EKEvent]()
                    for event in events {
                        // Only add events which do not have a Reccurence rule (YACA cannot deal with that (yet))
                        if let recRules = event.recurrenceRules {
                            if recRules.count == 0 {
                                self.events.append(event)
                            }
                        }
                    }
                    // MARK: - Feed datasource and let it do the job to structure probably for CollectionView
                    self.eventSource = Datasource(events: self.events)
                    completionHandler(result: true)
                })
            } else {
                completionHandler(result: false)
            }
        }
    }
    
    func fetchEvents(eventStore: EKEventStore, calendarIdentity: String, completed: ([EKEvent]) -> ()) {
        let endDate = NSDate(timeIntervalSinceNow: NSTimeInterval(self.duration))
        let predicate = eventStore.predicateForEventsWithStartDate(NSDate(), endDate: endDate, calendars: [self.eventStore.calendarWithIdentifier(calendarIdentity)!])
        
        //let events = NSMutableArray(array: eventStore.eventsMatchingPredicate(predicate))
        
        completed(eventStore.eventsMatchingPredicate(predicate) as [EKEvent]!)
    }
}

// MARK: - functions for keyboard dismiss
extension MeetingsViewController {
    
    func addKeyboardDismissRecognizer() {
        view.addGestureRecognizer(tapRecognizer!)
    }
    
    func removeKeyboardDismissRecognizer() {
        view.removeGestureRecognizer(tapRecognizer!)
    }
    
    func handleSingleTap(recognizer: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
}