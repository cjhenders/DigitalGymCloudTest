//
//  WorkoutSummary.swift
//  DigitalGymCloudTestwithUI
//
//  Created by Carl Henderson on 8/9/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Charts

class WorkoutSummary: UIViewController, NSFetchedResultsControllerDelegate, UITextFieldDelegate {
    
    
    //Mark: Variables
    @IBOutlet weak var workoutSummaryChart: LineChartView! // This is the lineChartView outlet
   
    
    var table2 : MSSyncTable?
    var store2 : MSCoreDataStore?
    
    lazy var fetchedResultController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "SessionData")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        
        // show only non-completed items
        fetchRequest.predicate = NSPredicate(format: "stampStart >= 0")
        
        // sort by item text
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "stampStart", ascending: true)]
        
        // Note: if storing a lot of data, you should specify a cache for the last parameter
        // for more information, see Apple's documentation: http://go.microsoft.com/fwlink/?LinkId=524591&clcid=0x409
        let resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        resultsController.delegate = self;
        
        return resultsController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        // Managing the clients for Syncing with Azure Sql
        
        let client = MSClient(applicationURLString: "http://mobile-flask-app.azurewebsites.net")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        self.store2 = MSCoreDataStore(managedObjectContext: managedObjectContext)
        client.syncContext = MSSyncContext(delegate: nil, dataSource: self.store2, callback: nil)
        self.table2 = client.syncTableWithName("SessionData")
        
        
        // Fetched Controller for Sql Server
        
        var error : NSError? = nil
        do {
            try self.fetchedResultController.performFetch()
        } catch let error1 as NSError {
            error = error1
            print("Unresolved error \(error), \(error?.userInfo)")
            abort()
        }
        
        // Refresh Data on Load
        
        onRefresh()
        makearrays()
        loaddataforsummary()
        
        // Navigation and UI Interaction
        self.navigationItem.hidesBackButton = true
        
        // Setting up the Chart
        
        let pace = WorkoutDataClass.sharedWorkoutDataClass.pacearray
        let time = WorkoutDataClass.sharedWorkoutDataClass.timearray
        
        setChart(time, values: pace)

        print (WorkoutDataClass.sharedWorkoutDataClass.pacearray)
        print(WorkoutDataClass.sharedWorkoutDataClass.timestamp)
        
    }
    
    func onRefresh() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        self.table2!.pullWithQuery(self.table2?.query(), queryId: "AllRecords") {
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
    
    // Mark: Actions

    
    
    
    // Mark: TextFields
    
    var genderText: String = "Male"
    var height : Float = 0
    var inchText: String = "0"
    var feetText: String = "4"
    var ageText: String = "1"
    var weightText: String = "50"
    
    
    
    
    // MARK: AddingItems

    
    //This restarts the workout as well as resets the global workout data that is located in the WorkoutDataClass.swift
    @IBAction func restartWorkout(sender: AnyObject) {
        WorkoutDataClass.sharedWorkoutDataClass.pacearray = []
        WorkoutDataClass.sharedWorkoutDataClass.timeelapsed = 0
        WorkoutDataClass.sharedWorkoutDataClass.timearray = []
        WorkoutDataClass.sharedWorkoutDataClass.timestamp = 0
    }
    
    
    //Mark: Label Connections
    
    
    @IBOutlet weak var secondElapsedSummary: UILabel!
    @IBOutlet weak var averageRPMLabel: UILabel!
    @IBOutlet weak var minElapsedSummary: UILabel!
    
    //Mark: Load up WorkoutData for Summary
    
    
    func loaddataforsummary() {
        
        //This calculates the average RPM for the workout and gathers time elapsed from the global WorkoutDataClass
        
        let pacearray = WorkoutDataClass.sharedWorkoutDataClass.pacearray
        var total: Double = 0
        
        for values in pacearray {
            total += Double(values)
        }
        
        let average = (Int(total)/pacearray.count)
        let timeelapsed = WorkoutDataClass.sharedWorkoutDataClass.timeelapsed
        let secondsElapsed = WorkoutDataClass.sharedWorkoutDataClass.minelapsed
        
        
        // This sets the labels to the values of the global workout data located in the WorkoutDataClass
        
        averageRPMLabel.text = String(average)
        secondElapsedSummary.text = String(timeelapsed)
        minElapsedSummary.text = String(secondsElapsed)
    }
    
    //Mark: Setting up the Chart
    //This sets up the chart used in the final view. It uses the swift charts frameworks. There is documentation online.
    
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
        workoutSummaryChart.data = lineChartData
        
        //Mark: Chart Properties
        workoutSummaryChart.xAxis.labelPosition = .Bottom
        workoutSummaryChart.animate(xAxisDuration: 1.25, yAxisDuration: 1.25, easingOption: .EaseInCubic)
        workoutSummaryChart.backgroundColor = UIColor(red: 189/255, green: 195/255, blue: 199/255, alpha: 1)

    }
    
    //Mark: Make Arrays for time values for chart. It is based off the number of items within the global pacearray in WorkoutDataClass
    
    func makearrays() {
        var time = 0
        for _  in 1...(WorkoutDataClass.sharedWorkoutDataClass.pacearray.count) {
            WorkoutDataClass.sharedWorkoutDataClass.timearray.append("\(time)")
            time += 4
        }
    }
    
    
}
