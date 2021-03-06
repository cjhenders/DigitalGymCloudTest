// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import Foundation
import UIKit
import CoreData

class BeginWorkoutViewController: UIViewController, NSFetchedResultsControllerDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    
    
    //Mark: Variables and Tables used for Sql Server
    
    //This initializes the Microsoft Table and Data stores for Azure Framework
    var table2 : MSSyncTable?
    var store2 : MSCoreDataStore?
    
    //This fetches data from the Sql Server by having semi-query seearches. The predicates are like more defined searches.
    lazy var fetchedResultController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "SessionData")
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
    
    //These are the items that are done first when the view is loaded.
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Managing the clients for Syncing with Azure Sql
        
        let client = MSClient(applicationURLString: "http://mobile-flask-app.azurewebsites.net")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        self.store2 = MSCoreDataStore(managedObjectContext: managedObjectContext)
        client.syncContext = MSSyncContext(delegate: nil, dataSource: self.store2, callback: nil)
        self.table2 = client.syncTableWithName("SessionData")
        //self.refreshControl?.addTarget(self, action: "onRefresh:", forControlEvents: UIControlEvents.ValueChanged)
        
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
        
        // Navigation and UI Interaction
        self.navigationItem.hidesBackButton = true
        
        print(WorkoutDataClass.sharedWorkoutDataClass.pacearray)
        print(WorkoutDataClass.sharedWorkoutDataClass.timestamp)
        print(WorkoutDataClass.sharedWorkoutDataClass.timeelapsed)

        
        
    }
    
    //This function is used throughout the app in order to sync the Core Data to the Azure Sql server by running a query of All Records. This is used typically on viewDidLoad and on any segue to a new view to refresh the table.
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
    
    //This outlines any actions called when the start workout button is hit.
    @IBAction func startWorkout(sender: AnyObject) {
        
        didSaveItem()
        onRefresh()
    }
    
  
    // Mark: TextFields
    //These are the default values used in the didSaveItem function because they are used incase of someone not putting in any data.
    
    var genderText: String = "Male"
    var height : Int = 0
    var inchText: String = "0"
    var feetText: String = "4"
    var ageText: String = "1"
    var weightText: String = "50"
    

   
    
    // MARK: AddingItems to Azure Sql Server
    
    func didSaveItem()
    {
        if inchText == "0" && feetText == "4" {
            height == 48
        }
        else {
            height = ((Int(feetText)! * 12) + (Int(inchText))!)
        }
        
        let gender = genderText
        let age = Int(ageText)
        let weight = Float(weightText)
        let timestamp = NSNumber(double: NSDate().timeIntervalSince1970)
        WorkoutDataClass.sharedWorkoutDataClass.timestamp = timestamp
        var itemToInsert: [String : AnyObject] = [:]
        
        
        //This is setting the itemToInsert for the Azure Sql Server
        
        if age != 1 && weight != 55 && height != 48 {
            itemToInsert = [ "gender": gender ,"complete": false, "age": age!, "weight": weight!, "stampStart": timestamp, "height": height,]
        }
        else {
            itemToInsert = ["stampStart": timestamp]
        }
        
        // This pice of code actually inserts the itme into the table. After inserting the item a onRefresh() should be run in order to sync the table with the Sql Server
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.table2!.insert(itemToInsert) {
            (item, error) in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if error != nil {
                print("Error: " + error!.description)
            }
        }
    }
    
    
    //Mark: PickerViewData
    //This is the data used for the pickerviews so that the user can choose the most appropriate description.
    
    let genderarray : [String] = ["Male","Female"]
    var agearray : [String] = []
    var weightarray : [String] = []
    let feetarray = ["4","5","6","7"]
    let incharray = ["0","1","2","3","4","5","6","7","8","9","10","11"]
    
    
    //Mark: Generate Age and Weight array
    //Makes the arrays for the pickerview data.
    func makearrays(){
        var age = 0
        var weight = 50
        for _ in 1...100 {
            age += 1
            agearray.append("\(age)")
        }
        
        for _ in 1...65 {
            weight += 5
            weightarray.append("\(weight)")
        }
    }
    
    
    
    
    //Mark: PickerViewSetup - This sets up all the pickerviews used on the first page to gather user information
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 1 {
            return 2
        } else if pickerView.tag == 2 {
            return agearray.count
        } else if pickerView.tag == 3 {
            return feetarray.count
        } else if pickerView.tag == 4{
            return incharray.count
        } else if pickerView.tag == 5{
            return weightarray.count
        } else  {
            return 4
        }
    }


    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView.tag == 1 {
            return genderarray[row]
        } else if pickerView.tag == 2 {
            return agearray[row]
        } else if pickerView.tag == 3 {
            return feetarray[row]
        } else if pickerView.tag == 4 {
            return incharray[row]
        } else if pickerView.tag == 5 {
            return weightarray[row]
        } else {
            return "?"
        }
    }
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 1 {
            genderText = genderarray[row]
        } else if pickerView.tag == 2 {
            ageText = agearray[row]
        } else if pickerView.tag == 3 {
           feetText = feetarray[row]
        } else if pickerView.tag == 4 {
            inchText = incharray[row]
        } else if pickerView.tag == 5 {
            weightText = weightarray[row]
        } else {
            return
        }
    }
}