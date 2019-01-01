//
//  CanvasViewController.swift
//  DailyPlanner
//
//  Created by Neelaksh Bhatia on 2018-11-05.
//  Copyright © 2018 Neelaksh Bhatia. All rights reserved.
//

import UIKit
import FSCalendar
import Floaty
import Sketch

class CanvasViewController: UIViewController, SketchViewDelegate, UIScrollViewDelegate {
    var containerView: UIView!
    var calendarView: FSCalendar!
    var sketchView: SketchView!
    var cachedImage: UIImage?
    var selectedDate: String!
    var scale: CGFloat = 1.0
    var saveTimer: Timer?
    var shouldSave: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let actionButton = Floaty()
        // fab action items
        actionButton.addItem("Erase", icon: UIImage(named: "clear")) { item in

            let alert = UIAlertController(title: "Warning", message: "Are you sure you want to clear this page?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { handler in
                self.sketchView.loadImage(image: UIImage())
                self.eraseCachedImage(imageName: self.selectedDate)
                self.calendarView.reloadData()
            })
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            self.present(alert, animated: true) {
                actionButton.close()
            }
        }

        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))

        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height + 300))
        self.containerView = containerView

        let sketchView = SketchView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height + 300))
        self.sketchView = sketchView

        if self.cachedImage != nil {
            sketchView.loadImage(image: self.cachedImage!)
        }

        sketchView.sketchViewDelegate = self

        view.addSubview(scrollView)

        containerView.addSubview(sketchView)
        scrollView.addSubview(containerView)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 2.5
        scrollView.contentSize = CGSize(width: sketchView.frame.width, height: sketchView.frame.height)

        scrollView.panGestureRecognizer.allowedTouchTypes = [0] // only finger
        scrollView.pinchGestureRecognizer?.allowedTouchTypes = [0]

        self.view.addSubview(actionButton)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let image = self.sketchView.image, shouldSave else { return }
        self.saveImage(imageName: self.selectedDate, image: image)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }

    func drawView(_ view: SketchView, willBeginDrawUsingTool tool: AnyObject) {
        if tool as? NSObject != NSNull() {
            self.saveTimer?.invalidate()
        }
    }
    func drawView(_ view: SketchView, didEndDrawUsingTool tool: AnyObject) {
        if tool as? NSObject != NSNull() {
            restartTimer()
            shouldSave = true
        }
    }

    func restartTimer() {
        self.saveTimer?.invalidate()
        self.saveTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { (Timer) in
            guard let image = self.sketchView.image else { return }
            print("fired")
            self.saveImage(imageName: self.selectedDate, image: image)
            self.calendarView.reloadData()
        }
    }

    func saveImage(imageName: String, image: UIImage) {
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let fileName = imageName
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        guard let data = image.pngData() else { return }

        //Checks if file exists, removes it if so.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(atPath: fileURL.path)
                print("Removed old image")
            } catch let removeError {
                print("couldn't remove file at path", removeError)
            }

        }

        do {
            print("write to ", fileURL.path)
            try data.write(to: fileURL)
        } catch let error {
            print("error saving file with error", error)
        }
    }

    func eraseCachedImage(imageName: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let fileName = imageName
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        //Checks if file exists, removes it if so.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                print("remove at ", fileURL.path)
                try FileManager.default.removeItem(atPath: fileURL.path)
                print("Erased stored image")
                self.shouldSave = false
                self.saveTimer?.invalidate()
            } catch let removeError {
                print("couldn't remove file at path", removeError)
            }

        }
    }

    @objc private func onPinch(_ gesture: UIPinchGestureRecognizer) {
        if let view = gesture.view {

            switch gesture.state {
            case .changed:
                let pinchCenter = CGPoint(x: gesture.location(in: view).x - view.bounds.midX,
                                          y: gesture.location(in: view).y - view.bounds.midY)
                let transform = view.transform.translatedBy(x: pinchCenter.x, y: pinchCenter.y)
                    .scaledBy(x: gesture.scale, y: gesture.scale)
                    .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)
                view.transform = transform
            case .ended:
                print(gesture.scale)
                UIView.animate(withDuration: 0.2, animations: {
                    view.transform = CGAffineTransform.identity
                })
            default:
                return
            }
        }
    }
}

extension CanvasViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.type != .pencil {
            return true
        }
        return false
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
