//
//  DetailViewController.swift
//  SFProgressDemo
//
//  Created by Edmond on 9/4/15.
//  Copyright © 2015 XueQiu. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {
    @IBOutlet weak var detailDescriptionLabel: UILabel!
    var hud: ProgressHUD!
    var timer: NSTimer!

    var detailItem: AnyObject? {
        didSet {
            self.configureView()
        }
    }

    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem, let label = self.detailDescriptionLabel {
            label.text = detail.description
            
            if label.text == "Simple Label" {
                hud = ProgressHUD.showHUD(view)
                hud.titleLabel.text = "SIMIPLE"
                hud.hide(true, afterDelay:3) 
            } else if label.text == "Detail label" {
                hud = ProgressHUD.showHUD(view)
                hud.titleLabel.text = "Loding\n Detail label"
                hud.hide(true, afterDelay:3)
            } else if label.text == "Detarminate model" {
                hud = ProgressHUD.showHUD(view)
                hud.mode = .Determinate
                hud.titleLabel.text = "Loding"
                progressTask()
            } else if label.text == "Annular width detarminate model" {
                hud = ProgressHUD.showHUD(view)
                hud.mode = .AnnularDeterminate
                hud.titleLabel.text = "Loding"
                progressTask()
            } else if label.text == "On window" {
                if let window = UIApplication.sharedApplication().delegate?.window {
                    hud = ProgressHUD.showHUD(window!)
                    hud.hide(true, afterDelay:3)
                }
            } else if label.text == "Custom View" {
                hud = ProgressHUD.showHUD(view)
                hud.mode = .CustomView
                hud.titleLabel.text = "Complete"
                hud.customView = UIImageView(image: UIImage(named:"check"))
                hud.hide(true, afterDelay:3)
            }
        }
    }
    
    func progressTask() {
        // This just increases the progress indicator in a loop
        timer = NSTimer.scheduledTimerWithTimeInterval(0.01, target:self, selector:#selector(updateTimer), userInfo: nil, repeats:true)
        NSRunLoop.currentRunLoop().addTimer(timer!, forMode:NSRunLoopCommonModes)
    }
    
    var progress : Float = 0.0
    @objc private func updateTimer() {
        progress += 0.01
        hud!.progress = progress
        if progress >= 1.0 {
            progress = 0.00
            hud.hide()
            timer!.invalidate()
            timer = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
    }
}

