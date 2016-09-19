//
//  WorkoutDataViewController.swift
//  DigitalGymCloudTest
//
//  Created by Carl Henderson on 8/3/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Charts

class WorkoutDataViewController: UIViewController, NSFetchedResultsControllerDelegate {
    
    // Mark: Properties and Variables
    
    //This sets start data that is used later on, especially in the counters.
    
    var timer = NSTimer()
    var datatimer = NSTimer()
    var seccounter = 0
    var mincounter = 0
    var table : MSSyncTable?
    var store : MSCoreDataStore?
    
    lazy var fetchedResultController: NSFetchedResultsController = {
        let timestamp = Int(WorkoutDataClass.sharedWorkoutDataClass.timestamp)
        let fetchRequest = NSFetchRequest(entityName: "Id117")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        
        // show only non-completed items
        fetchRequest.predicate = NSPredicate(format: "deleted = false")
        
        // sort by item text
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "stamp", ascending: true)]
        
        // Note: if storing a lot of data, you should specify a cache for the last parameter
        // for more information, see Apple's documentation: http://go.microsoft.com/fwlink/?LinkId=524591&clcid=0x409
        let resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
   
        resultsController.delegate = self;
        
        return resultsController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        print ("second view")
        
        let client = MSClient(applicationURLString: "http://mobile-flask-app.azurewebsites.net")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        self.store = MSCoreDataStore(managedObjectContext: managedObjectContext)
        client.syncContext = MSSyncContext(delegate: nil, dataSource: self.store, callback: nil)
        self.table = client.syncTableWithName("Id117")
        //self.refreshControl?.addTarget(self, action: "onRefresh:", forControlEvents: UIControlEvents.ValueChanged)
        
        
        var error : NSError? = nil
        do {
            try self.fetchedResultController.performFetch()
        } catch let error1 as NSError {
            error = error1
            print("Unresolved error \(error), \(error?.userInfo)")
            abort()
        }
        
        onRefresh()
        
        
        //Mark: Navigation Items

        self.navigationItem.hidesBackButton = true
        
        // Timer Initilization
        starttimer()
        
        //Mark: Data pull
        startdatacollection()
        

    }
    
    func onRefresh() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        self.table!.pullWithQuery(self.table?.query(), queryId: "AllRecords") {
            (error) -> Void in
            
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            
            if error != nil {
                // A real application would handle various errors like network conditions,
                // server conflicts, etc via the MSSyncContextDelegate
                print("Error: \(error!.description)")
                
                // We will just discard our changes and keep the servers copy for simplicity
                if let opErrors = error!.userInfo[MSErrorPushResultKey] as? Array<MSTableOperationError> {
                    for opError in opErrors {
                        print("Attempted operation to item \(opError.itemId)")
                        if (opError.operation == .Insert || opError.operation == .Delete) {
                            print("Insert/Delete, failed discarding changes")
                            opError.cancelOperationAndDiscardItemWithCompletion(nil)
                        } else {
                            print("Update failed, reverting to server's copy")
                            opError.cancelOperationAndUpdateItem(opError.serverItem!, completion: nil)
                        }
                    }
                }
            }
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Timer Control used to start Time Elapsed Timer
    
    //These are the timers used to start the timers to measure workout duration.
    
    func starttimer(){
        timeLabel.text = String(seccounter)
        minTimeLabel.text = String(mincounter)
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target:self, selector: #selector(WorkoutDataViewController.updatecounter), userInfo: nil, repeats: true)
    }
    
    func updatecounter(){
        if seccounter == 60 {
            seccounter = 0
            mincounter = mincounter + 1
            minTimeLabel.text = String(mincounter)
            timeLabel.text = String(seccounter)
        } else{
        timeLabel.text = String(seccounter++)
        }
    }

    
    // Mark: Labels
    //These are the label outlets so that you can push data to view. These correspond to the time label(seconds), rpm label, and min label.
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var latestRPMLabel: UILabel!
    @IBOutlet weak var minTimeLabel: UILabel!
    
    //Mark: Data Acquistion Functions that start the pulling of data
    
    func startdatacollection() {
        datatimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: #selector(WorkoutDataViewController.configureData), userInfo: nil, repeats: true)
    }
    
    // This function does a fetch request to see the latest item created in the table and then pulls it and sets the text label to the value of he latest row.
    
    func configureData() {
        
            //These following lines are used to query the sql server for data after after a certain timestamp so we can then use it to get data.
        
            onRefresh()
        
            let fetchRequest = NSFetchRequest(entityName: "Id117")
        
            // show only non-completed items
            fetchRequest.predicate = NSPredicate(format: "deleted != true ")
        
            // sort by item text
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "stamp", ascending: true)]
        
            let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
 
            var error : NSError? = nil
            var resultsof:[AnyObject] = []
            do {
                resultsof = try managedObjectContext.executeFetchRequest(fetchRequest)
            
            } catch let error1 as NSError {
                error = error1
                print("Unresolved error \(error), \(error?.userInfo)")
                abort()
            }
        
            //These following lines get the valueforKey so that the LatestRPMLabel can be set to the most recently added value to the sql Server.
        
            let countofitems = resultsof.count
            let recentitem = (countofitems - 1)
            var text = ""
            var age = ""
            print(countofitems)
        
            if countofitems == 0 {
                text = ""
            } else {
                let rpm = ((resultsof[recentitem].valueForKey("x") as! Double))
                print(rpm)
                text = String(rpm)
                
            }
            latestRPMLabel.text = String(text)
            /*
            let rpm2 = ((resultsof[recentitem-2].valueForKey("stamp") as! Double))
            print(rpm2)
            let rpm3 = ((resultsof[recentitem-3].valueForKey("stamp") as! Double))
            print(rpm3)
            let rpm4 = ((resultsof[recentitem-4].valueForKey("stamp") as! Double))
            print(rpm4)
            let rpm5 = ((resultsof[recentitem-5].valueForKey("stamp") as! Double))
            print(rpm5)
            */
        
            //WorkoutDataClass.sharedWorkoutDataClass.pacearray.append(Double(text)!)

        

    }
    
    // MARK: Actions

    //This buttons ends the workout and invalidates all timers and sends any necessary to global WorkoutDataClass
    @IBAction func endWorkout(sender: AnyObject) {
        if WorkoutDataClass.sharedWorkoutDataClass.pacearray.count == 0 {
            WorkoutDataClass.sharedWorkoutDataClass.pacearray = [0]
        }
        //This stops all the timers for the workout and makes the workout completed true.
        
        datatimer.invalidate()
        timer.invalidate()
        
        //This  sets the minutes and seconds elapsed time labels so they can used in the WorkoutSummary. They are added to the GLobal Workout Data Class
        
        WorkoutDataClass.sharedWorkoutDataClass.timeelapsed = Int(timeLabel.text!)!
        WorkoutDataClass.sharedWorkoutDataClass.minelapsed = Int(minTimeLabel.text!)!
        
        //This is used to sync the WorkoutData to the pace array in the Global Workout Data Class so it can be used in the Chart in the WorkoutSummary page. It first queries data for a certain timestamp and adds all the values to the pace array.
        /*
        onRefresh()
        
        let timestamp = Int(WorkoutDataClass.sharedWorkoutDataClass.timestamp)
      
        
        let fetchRequest = NSFetchRequest(entityName: "UserDataTable")
        
        // show only non-completed items
        fetchRequest.predicate = NSPredicate(format: "startstamp >= \(timestamp) ")
        
        // sort by item text
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startstamp", ascending: true)]
        
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        
        var error : NSError? = nil
        var resultsof:[AnyObject] = []
        do {
            resultsof=try managedObjectContext.executeFetchRequest(fetchRequest)
            
        } catch let error1 as NSError {
            error = error1
            print("Unresolved error \(error), \(error?.userInfo)")
            abort()
        }
        print("Before")
        print(WorkoutDataClass.sharedWorkoutDataClass.pacearray)
        print(resultsof.count)
        for i in 0...(resultsof.count - 1) {
            let number = (resultsof[i].valueForKey("weight") as? Double)!
            WorkoutDataClass.sharedWorkoutDataClass.pacearray.append(Double(number))
            print(WorkoutDataClass.sharedWorkoutDataClass.pacearray)
        }
        */
}
}


   