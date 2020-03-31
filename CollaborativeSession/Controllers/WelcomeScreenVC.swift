//
//  WelcomeScreenVC.swift
//  MemoAR
//
//  Created by tarek ait hamouda on 2020-03-30.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit
class WelcomeScreenVC: UIViewController {
    
    @IBOutlet weak var startBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }

    @IBAction func onStartClick(_ sender: Any) {
        self.performSegue(withIdentifier: "goToSignIn", sender: self)
    }
}
