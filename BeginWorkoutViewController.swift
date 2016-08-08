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
    
    
    //Mark: Variables
    
    var table2 : MSSyncTable?
    var store2 : MSCoreDataStore?
    
    lazy var fetchedResultController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "UserDataTable")
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
        
        // Managing the clients for Syncing with Azure Sql
        
        let client = MSClient(applicationURLString: "https://digitalgymcloudtest.azurewebsites.net")
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        self.store2 = MSCoreDataStore(managedObjectContext: managedObjectContext)
        client.syncContext = MSSyncContext(delegate: nil, dataSource: self.store2, callback: nil)
        self.table2 = client.syncTableWithName("UserDataTable")
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
        
        // Navigation and UI Interaction
        
        self.weightText.delegate = self
        
        
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
    
    @IBAction func startWorkout(sender: AnyObject) {
        
        didSaveItem()
        onRefresh()
    }

    // Mark: Navigation and UI Interaction
    
    // Results in Keyboard to Disappear after hitting enter
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        weightText.resignFirstResponder()
        return true
    }
    
    
  
    // Mark: TextFields
    
    var genderText: String = "Male"
    var height : Float = 0
    @IBOutlet weak var ageText: UITextField!
    @IBOutlet weak var weightText: UITextField!
    @IBOutlet weak var feetText: UITextField!
    @IBOutlet weak var inchText: UITextField!

   
    
    // MARK: AddingItems
    
    func didSaveItem()
    {
        if inchText.text != "" || feetText.text != "" {
        height = ((Float(feetText.text!)! * 12) + Float(inchText.text!)!)
        }
        else{
            height = 0
        }
        let gender = genderText
        let age = Float(ageText.text!)
        let weight = Float(weightText.text!)
        let timestamp = Float(NSDate().timeIntervalSince1970)
        var itemToInsert: [String : AnyObject] = [:]
        
        // We set created at to now, so it will sort as we expect it to post the push/pull
        if age != nil || weight != nil || height != 0 {
            itemToInsert = ["gender": gender, "complete": false , "age": age!, "weight": weight!, "startstamp": timestamp, "height": height ]
        }
        else {
            itemToInsert = ["startstamp": timestamp]
        }
        
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
    
    let genderarray : [String] = ["Male","Female"]
    
    //Mark: PickerViewSetup
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 1 {
            return 2
        /*}else if pickerView.tag == 2 {
            return agearray.count
        }else if pickerView.tag == 3 {
            return heightarray.count
        } else {
            return weightarray.count
        */
        } else{
            return 1
        }
    }
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView.tag == 1 {
            return genderarray[row]
        }
        else {
            return "?"
        }
    }
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
             genderText = genderarray[row]
       
}
}