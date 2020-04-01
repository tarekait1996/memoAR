//
//  JoinViewController.swift
//  MemoAR
//
//  Created by tarek ait hamouda on 2020-03-31.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class JoinViewController: UIViewController {

    @IBOutlet weak var hostID: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func goToARCamera(_ sender: Any) {
        performSegue(withIdentifier: "goToARCamera", sender: self)

    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
