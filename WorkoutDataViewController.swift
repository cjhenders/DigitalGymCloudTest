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
    @IBOutlet weak var lineChartView: LineChartView!
    
    var workoutcompleted: Bool = false
    var timer = NSTimer()
    var datatimer = NSTimer()
    var seccounter = 0
    var mincounter = 0
    var table : MSSyncTable?
    var store : MSCoreDataStore?
    
    lazy var fetchedResultController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "TodoItem")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        
        // show only non-completed items
        fetchRequest.predicate = NSPredicate(format: "complete != true")
        
        // sort by item text
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        // Note: if storing a lot of data, you should specify a cache for the last parameter
        // for more information, see Apple's documentation: http://go.microsoft.com/fwlink/?LinkId=524591&clcid=0x409
        let resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
   
        resultsController.delegate = self;
        
        return resultsController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let pace = [10.0,5.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
        let time = ["1.0","2.0","3.0","4.0","5.0","6.0","7.0","8.0","9.0","10.0"]
        
        setChart(time, values: pace)
        
        
        let client = MSClient(applicationURLString: "https://digitalgymcloudtest.azurewebsites.net")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        self.store = MSCoreDataStore(managedObjectContext: managedObjectContext)
        client.syncContext = MSSyncContext(delegate: nil, dataSource: self.store, callback: nil)
        self.table = client.syncTableWithName("TodoItem")
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
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var latestRPMLabel: UILabel!
    @IBOutlet weak var minTimeLabel: UILabel!
    
    //Mark: Data Acquistion Functions that start the pulling of data
    
    func startdatacollection() {
        datatimer = NSTimer.scheduledTimerWithTimeInterval(4, target: self, selector: #selector(WorkoutDataViewController.configureData), userInfo: nil, repeats: true)
    }
    
    // This function does a fetch request to see the latest item created in the table and then pulls it and sets the text label to the value of he latest row.
    func configureData() {
    
            onRefresh()
        
            let fetchRequest = NSFetchRequest(entityName: "TodoItem")
        
            // show only non-completed items
            fetchRequest.predicate = NSPredicate(format: "complete != true")
        
            // sort by item text
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
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
        
        

            let countofitems = resultsof.count
            let recentitem = (countofitems - 1)
            var text = ""
        
            if countofitems == 0 {
                text = ""
            } else {
                text = (resultsof[recentitem].valueForKey("text") as? String)!
            }
        
            latestRPMLabel.text = text
        
            WorkoutDataClass.sharedWorkoutDataClass.pacearray.append(Double(text)!)

    }
    
    // MARK: Actions

    //This buttons ends the workout and invalidates all timers and sends any necessary to global WorkoutDataClass
    @IBAction func endWorkout(sender: AnyObject) {
        workoutcompleted = true
        datatimer.invalidate()
        timer.invalidate()
        
        WorkoutDataClass.sharedWorkoutDataClass.timeelapsed = Int(timeLabel.text!)!
        
        
       
    }
    
    
    // MARK: - ToDoItemDelegate
    
    
    func didSaveItem(text: String)
    {
        if text.isEmpty {
            return
        }
        
        // We set created at to now, so it will sort as we expect it to post the push/pull
        let itemToInsert = ["text": text, "complete": false, "__createdAt": NSDate()]
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.table!.insert(itemToInsert) {
            (item, error) in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if error != nil {
                print("Error: " + error!.description)
            }
        }
    }
    
    
    

    //Mark: Chart Data used to Chart Characteristics look up swift charts for documentation
    
    func setChart(dataPoints: [String], values: [Double]) {
        
        var dataEntries: [ChartDataEntry] = []
        
        for i in 0..<dataPoints.count {
            let dataEntry = ChartDataEntry(value: values[i], xIndex: i)
            dataEntries.append(dataEntry)
        }
        
        var colors: [UIColor] = []
        
        for i in 0..<dataPoints.count {
            let red = Double(arc4random_uniform(256))
            let green = Double(arc4random_uniform(256))
            let blue = Double(arc4random_uniform(256))
            
            let color = UIColor(red: CGFloat(red/255), green: CGFloat(green/255), blue: CGFloat(blue/255), alpha: 1)
            colors.append(color)
        }
        
        
        
        
        let lineChartDataSet = LineChartDataSet(yVals: dataEntries, label: "Pace (RPM)")
        let lineChartData = LineChartData(xVals: dataPoints,dataSet: lineChartDataSet)
        lineChartView.data = lineChartData
        
        //Mark: Chart Properties
        lineChartView.xAxis.labelPosition = .Bottom
        lineChartView.animate(xAxisDuration: 1.25, yAxisDuration: 1.25, easingOption: .EaseInCubic)
        lineChartView.backgroundColor = UIColor(red: 189/255, green: 195/255, blue: 199/255, alpha: 1)

    }
    
}
