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
    
    // Mark: Properties
    @IBOutlet weak var lineChartView: LineChartView!
    
    
    
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
        
        let fetchRequest = NSFetchRequest(entityName: "TodoItem")
        
        // show only non-completed items
        fetchRequest.predicate = NSPredicate(format: "complete != true")
        
        // sort by item text
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]


        
        var resultsof:[AnyObject] = []
        do {
             resultsof=try managedObjectContext.executeFetchRequest(fetchRequest)

        } catch let error1 as NSError {
            error = error1
            print("Unresolved error \(error), \(error?.userInfo)")
            abort()
        }

        
        print("test log")
        print(resultsof.count)
        
        // Refresh data on load
        //self.refreshControl?.beginRefreshing()
        //self.onRefresh(self.refreshControl)
        
        //configureData()
        
        //let indexPath = NSIndexPath(forRow:1, inSection: 1)
        //let item = self.fetchedResultController.objectAtIndexPath(indexPath) as! NSManagedObject
        

        //let item = fetchedResultController
        //var countofitems = resultsof.count
        //let recentitem = (countofitems - 1)
        
        //let text = resultsof[recentitem].valueForKey("text") as? String
        
        //let subtitle = item.valueForKey("subtitle") as? String
        
        //timeLabel.text = text
        //timeLabel.text = "hello"

        self.navigationItem.hidesBackButton = true

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
     
     //self.refreshControl?.endRefreshing()
     }
     }
 
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Table Controls

    
    // Mark: Labels
    @IBOutlet weak var timeElapsedLabel: UILabel!
    @IBOutlet weak var latestRPMLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    func configureData() {
        
        do {
            try self.fetchedResultController.performFetch()
        }
        catch {
            print("Error")
        }
        
        let indexPath = NSIndexPath(forRow:0, inSection: 0)
        let item = self.fetchedResultController.objectAtIndexPath(indexPath) as! NSManagedObject
        
        let text = item.valueForKey("text") as? String
        
        let subtitle = item.valueForKey("subtitle") as? String
        
        latestRPMLabel.text = text
        timeLabel.text = "hello"
    }
    
    // MARK: Navigation
    
    
    
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
    
    
    // MARK: - NSFetchedResultsDelegate
    
    /*
     func controllerWillChangeContent(controller: NSFetchedResultsController) {
     dispatch_async(dispatch_get_main_queue(), { () -> Void in
     //self.tableView.beginUpdates()
     });
     }
     
     func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
     
     dispatch_async(dispatch_get_main_queue(), { () -> Void in
     let indexSectionSet = NSIndexSet(index: sectionIndex)
     if type == .Insert {
     //self.tableView.insertSections(indexSectionSet, withRowAnimation: .Fade)
     } else if type == .Delete {
     //self.tableView.deleteSections(indexSectionSet, withRowAnimation: .Fade)
     }
     })
     }
     
     func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
     
     dispatch_async(dispatch_get_main_queue(), { () -> Void in
     //switch type {
     //case .Insert:
     //self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
     //case .Delete:
     //self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
     //case .Move:
     //self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
     //self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
     //case .Update:
     // note: Apple samples show a call to configureCell here; this is incorrect--it can result in retrieving the
     // wrong index when rows are reordered. For more information, see:
     // http://go.microsoft.com/fwlink/?LinkID=524590&clcid=0x409
     //self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: .Automatic)
     //}
     //})
     //}
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
     dispatch_async(dispatch_get_main_queue(), { () -> Void in
     //self.tableView.endUpdates()
     });
     }
 
    
    */
    //Mark: PickerViewData
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
