//
//  CircularProgressBarView.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 20.09.2021.
//

import UIKit

class CircularProgressBarView: UIView {
    
    // MARK: - Properties
    private var progressLayer = CAShapeLayer()
    private var startPoint = -CGFloat.pi/2
    private var endPoint = 2*CGFloat.pi
    
    // MARK: - Initialisation
    override init(frame: CGRect) {
        super.init(frame: frame)
        createCircularPath()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        createCircularPath()
    }
    
    // MARK: - Methods
    private func createCircularPath() {
        let circularPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.width/2).cgPath
        
        let circleLayer = CAShapeLayer()
        circleLayer.path = circularPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.lineCap = .round
        circleLayer.lineWidth = 3.0
        layer.addSublayer(circleLayer)
        
        progressLayer.path = circularPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.black.cgColor
        progressLayer.lineCap = .butt
        progressLayer.lineWidth = 4.0
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }
    
    func progressAnimation(duration: TimeInterval) {
        let circularProgressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        circularProgressAnimation.duration = duration
        circularProgressAnimation.toValue = 1.0
        circularProgressAnimation.fillMode = .forwards
        circularProgressAnimation.isRemovedOnCompletion = false
        progressLayer.add(circularProgressAnimation, forKey: "progressAnimation")
    }
}
