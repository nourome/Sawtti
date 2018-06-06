//
//  CoolBtnView.swift
//  sawtti
//
//  Created by Nour on 06/03/2018.
//  Copyright © 2018 Nour Saffaf. All rights reserved.
//

import UIKit
@IBDesignable class CoolBtnView: UIView {
   
    private let duration: CFTimeInterval = 15.0
    private let timerCircle = CAShapeLayer()
    private let gradientLayer: CAGradientLayer = {
       let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0.5,y: 0.7)
        gradient.endPoint = CGPoint(x: 0.0, y: 0.0)
        
        let locations:[NSNumber]  = [
            0.15,
            0.5,
            0.85
        ]
        gradient.locations = locations
        return gradient
     
    }()

    var button = UIButton()
  
    private let logoImage: UIImageView = {
        let image = UIImage(named: "logo", in: Bundle.main, compatibleWith: nil)
        let imageView = UIImageView(image: image)
        return imageView
    }()
    
    private let emmiterCell: CAEmitterCell = {
        let cell = CAEmitterCell()
        cell.contents = UIImage(named: "fill_circle", in: Bundle.main, compatibleWith: nil)?.cgImage
        cell.lifetime = 2.0
        cell.velocity = 1
        cell.scaleSpeed = 0.3
        cell.birthRate = 0.0
        cell.velocityRange = 45
        return cell
    }()
    
    private let emitter : CAEmitterLayer = {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = kCAEmitterLayerCircle
        emitter.emitterSize = CGSize(width: 100, height: 100)
        return emitter
    }()
    
    
   
    
    @IBInspectable
    var gradientColor1: UIColor = UIColor(red: CGFloat(219.0/255.0), green: CGFloat(183.0/255.0), blue: CGFloat(120.0/255.0), alpha: 1.0) {
        didSet {
            initTimerCircle()
        }
    }
    @IBInspectable
    var gradientColor2: UIColor = UIColor(red: CGFloat(207.0/255.0), green: CGFloat(180.0/255.0), blue: CGFloat(221.0/255.0), alpha: 1.0) {
        didSet {
            initTimerCircle()
        }
    }
   
    @IBInspectable
    var emitterColorSoft: UIColor = UIColor(red: CGFloat(219.0/255.0), green: CGFloat(183.0/255.0), blue: CGFloat(120.0/255.0), alpha: 1.0)
    @IBInspectable
    var emitterColorMeduim: UIColor = UIColor(red: CGFloat(219.0/255.0), green: CGFloat(183.0/255.0), blue: CGFloat(120.0/255.0), alpha: 1.0)
    @IBInspectable
    var emitterColorHard: UIColor = UIColor(red: CGFloat(219.0/255.0), green: CGFloat(183.0/255.0), blue: CGFloat(120.0/255.0), alpha: 1.0)
    @IBInspectable
    var emitterColorLaud: UIColor = UIColor(red: CGFloat(219.0/255.0), green: CGFloat(183.0/255.0), blue: CGFloat(120.0/255.0), alpha: 1.0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupEmitter()
        createButton()
        initTimerCircle()
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setupEmitter()
        createButton()
        initTimerCircle()
        
    }
    
    func initTimerCircle(){
        let raduis = (button.bounds.width / 2) - 7
        timerCircle.path = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY), radius: raduis, startAngle: 0.0, endAngle: CGFloat(Double.pi * 2.0), clockwise: false).cgPath
        timerCircle.fillColor = UIColor.clear.cgColor
        timerCircle.strokeColor = UIColor.red.cgColor
        timerCircle.lineWidth = 14
        timerCircle.frame = bounds
    
        gradientLayer.colors = [gradientColor1.cgColor, gradientColor2.cgColor]
        gradientLayer.frame = bounds
       
        gradientLayer.mask = timerCircle
        layer.addSublayer(gradientLayer)
    
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
       
    }
    
    
    func createButton() {
      
        button.translatesAutoresizingMaskIntoConstraints = false
        button.frame = CGRect(x: bounds.midX, y: bounds.midY, width: 200, height: 200)
        let btnImage = UIImage(named: "btn_n", in: Bundle.main, compatibleWith: nil)
        button.setImage(btnImage, for: .normal)
        addSubview(button)
        button.heightAnchor.constraint(equalToConstant: 200.0).isActive = true
        button.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
        button.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
         button.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        logoImage.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoImage)
        logoImage.heightAnchor.constraint(equalToConstant: 130).isActive = true
        logoImage.widthAnchor.constraint(equalToConstant: 130).isActive = true
        logoImage.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        logoImage.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        
    }
    
    func setupEmitter(){
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emmiterCell.color = emitterColorSoft.cgColor
        emitter.emitterCells = [emmiterCell]
        
        layer.addSublayer(emitter)
    }
    
    func animateCountDown(){
            let animateTime = CABasicAnimation(keyPath: "strokeEnd")
            animateTime.duration = duration
            animateTime.fromValue = 1.0
            animateTime.toValue = 0.0
            animateTime.isRemovedOnCompletion = false
            animateTime.fillMode = kCAFillModeBoth
            timerCircle.add(animateTime, forKey: "CountDown")
    }
    
    func stopCountDownAnimatation() {
        timerCircle.removeAllAnimations()
        timerCircle.strokeEnd = 1.0
    }
    
    func fireEmitter(value: Float){
        emmiterCell.birthRate = 8.0
        //let valueInt = Int(value)
        
        switch value {
        case 0..<0.4:
            emmiterCell.color = emitterColorSoft.cgColor
            emmiterCell.velocity = 1
            emmiterCell.lifetime = 1.0
        case 0.4..<0.8:
            emmiterCell.color = emitterColorMeduim.cgColor
             emmiterCell.scaleSpeed = 0.15
             emmiterCell.lifetime = 1.4
             emmiterCell.velocity = 2
        case 0.8..<1.2:
            emmiterCell.color = emitterColorHard.cgColor
             emmiterCell.velocity = 3
            emmiterCell.lifetime = 1.8
        default:
           emmiterCell.color = emitterColorLaud.cgColor
           emmiterCell.lifetime = 2.5
           emmiterCell.velocity = 4
        }
        
        emitter.emitterCells = [emmiterCell]
    }
    
    func stopEmitter() {
        //emmiterCell.birthRate = 0.0
        emitter.emitterCells = []
    }
    
    /*
        override func layoutSubviews() {
            super.layoutSubviews()
            startButton.frame = CGRect(x: 0, y: 0, width: frame.width-10.0, height: frame.height-10.0)
            /*
            startButton.topAnchor.constraintEqualToSystemSpacingBelow(self.topAnchor, multiplier: 10.0)
             startButton.bottomAnchor.constraintEqualToSystemSpacingBelow(self.bottomAnchor, multiplier: 10.0)
            startButton.leftAnchor.constraintEqualToSystemSpacingAfter(self.leftAnchor, multiplier: 10.0)
            startButton.rightAnchor.constraintEqualToSystemSpacingAfter(self.rightAnchor, multiplier: 10.0)
 */
 
        }
        */
    /*
        override func didMoveToWindow() {
           // addSubview(startButton)
        }
        */
        /*
         // Only override draw() if you perform custom drawing.
         // An empty implementation adversely affects performance during animation.
         override func draw(_ rect: CGRect) {
         // Drawing code
         }
         */
        
}

