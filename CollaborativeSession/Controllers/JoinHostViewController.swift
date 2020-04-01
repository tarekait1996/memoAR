//
//  JoinHostViewController.swift
//  MemoAR
//
//  Created by tarek ait hamouda on 2020-03-31.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit

class JoinHostViewController: UIViewController {

    @IBOutlet weak var JoinBtn: UIButton!
    @IBOutlet weak var HostBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func onJoinClick(_ sender: Any) {
        performSegue(withIdentifier: "goToJoinVC", sender: self)
    }
    @IBAction func onHostBtn(_ sender: Any) {
        performSegue(withIdentifier: "goToHostVC", sender: self)
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
