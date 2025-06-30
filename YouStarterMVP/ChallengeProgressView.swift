// ChallengeProgressView.swift
// YouStarterMVP

import UIKit

class ChallengeProgressView: UIView {

    var totalSegments: Int = 30 {
        didSet { setNeedsDisplay() }
    }
    var completedSegments: Int = 0 {
        didSet { setNeedsDisplay() }
    }
    var completedColor: UIColor = .systemRed {
        didSet { setNeedsDisplay() }
    }
    var remainingColor: UIColor = .lightGray {
        didSet { setNeedsDisplay() }
    }
    var segmentSpacing: CGFloat = 2.0 {
        didSet { setNeedsDisplay() }
    }

    private let sayingLabel: UILabel
    private var animationLayer: CAShapeLayer?
    private var animatedSegments: Int = 0

    override init(frame: CGRect) {
        sayingLabel = UILabel()
        super.init(frame: frame)
        setupSayingLabel()
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        sayingLabel = UILabel()
        super.init(coder: coder)
        setupSayingLabel()
        backgroundColor = .clear
    }

    private func setupSayingLabel() {
        sayingLabel.textAlignment = .center
        sayingLabel.numberOfLines = 0
        sayingLabel.font = UIFont.boldSystemFont(ofSize: 18) // Adjusted font size for better fit
        sayingLabel.textColor = .darkGray
        sayingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sayingLabel)

        NSLayoutConstraint.activate([
            sayingLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sayingLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            sayingLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.6) // Better fit for larger inner circle
        ])
    }

    var sayingText: String? {
        didSet {
            sayingLabel.text = sayingText
        }
    }
    
    // Animate progress from 0 to current completed segments
    func animateProgress() {
        guard completedSegments > 0, totalSegments > 0 else { return }
        
        // Remove existing animation layer
        animationLayer?.removeFromSuperlayer()
        
        // Create new animation layer
        animationLayer = CAShapeLayer()
        guard let animationLayer = animationLayer else { return }
        
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let outerRadius = min(bounds.width, bounds.height) / 2
        let innerRadius = outerRadius * 0.75
        
        // Create path for completed segments
        let completedPath = UIBezierPath()
        let anglePerSegment = (2 * Double.pi) / CGFloat(totalSegments)
        
        for i in 0..<completedSegments {
            let startAngle = anglePerSegment * CGFloat(i) - (Double.pi / 2)
            let endAngle = anglePerSegment * CGFloat(i + 1) - (Double.pi / 2)
            
            let segmentPath = UIBezierPath()
            segmentPath.addArc(withCenter: center,
                              radius: outerRadius - segmentSpacing,
                              startAngle: startAngle,
                              endAngle: endAngle,
                              clockwise: true)
            segmentPath.addLine(to: CGPoint(x: center.x + innerRadius * Foundation.cos(endAngle),
                                           y: center.y + innerRadius * Foundation.sin(endAngle)))
            segmentPath.addArc(withCenter: center,
                              radius: innerRadius,
                              startAngle: endAngle,
                              endAngle: startAngle,
                              clockwise: false)
            segmentPath.close()
            
            completedPath.append(segmentPath)
        }
        
        // Configure animation layer
        animationLayer.path = completedPath.cgPath
        animationLayer.fillColor = completedColor.cgColor
        animationLayer.strokeColor = UIColor.clear.cgColor
        
        // Add mask for revealing animation
        let maskLayer = CAShapeLayer()
        let maskPath = UIBezierPath()
        
        // Create a wedge that will grow from top clockwise
        let totalAngle = (2 * Double.pi) * (CGFloat(completedSegments) / CGFloat(totalSegments))
        maskPath.move(to: center)
        maskPath.addLine(to: CGPoint(x: center.x, y: center.y - outerRadius))
        maskPath.addArc(withCenter: center,
                       radius: outerRadius,
                       startAngle: -Double.pi / 2,
                       endAngle: -Double.pi / 2 + totalAngle,
                       clockwise: true)
        maskPath.close()
        
        maskLayer.path = maskPath.cgPath
        animationLayer.mask = maskLayer
        
        // Add to view
        layer.addSublayer(animationLayer)
        
        // Animate mask path instead of rotation for better effect
        let pathAnimation = CABasicAnimation(keyPath: "path")
        
        // Start with no wedge
        let startMaskPath = UIBezierPath()
        startMaskPath.move(to: center)
        startMaskPath.addLine(to: CGPoint(x: center.x, y: center.y - outerRadius))
        startMaskPath.addLine(to: center)
        startMaskPath.close()
        
        pathAnimation.fromValue = startMaskPath.cgPath
        pathAnimation.toValue = maskPath.cgPath
        pathAnimation.duration = 1.5
        pathAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        maskLayer.add(pathAnimation, forKey: "pathAnimation")
    }

    override func draw(_ rect: CGRect) {
        // Drawing segmented progress ring (static background)
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let outerRadius = min(bounds.width, bounds.height) / 2

        // Ensure valid radii and totalSegments to prevent crashes
        guard outerRadius > segmentSpacing, totalSegments > 0 else { return }

        let innerRadius = outerRadius * 0.75 // Make inner circle even larger for better text display
        guard innerRadius > 0 else { return }

        let anglePerSegment = (2 * Double.pi) / CGFloat(totalSegments)

        // Draw all segments as remaining (gray) first
        for i in 0..<totalSegments {
            let startAngle = anglePerSegment * CGFloat(i) - (Double.pi / 2)
            let endAngle = anglePerSegment * CGFloat(i + 1) - (Double.pi / 2)

            let path = UIBezierPath()
            path.addArc(withCenter: center,
                        radius: outerRadius - segmentSpacing,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: true)
            path.addLine(to: CGPoint(x: center.x + innerRadius * Foundation.cos(endAngle),
                                     y: center.y + innerRadius * Foundation.sin(endAngle)))
            path.addArc(withCenter: center,
                        radius: innerRadius,
                        startAngle: endAngle,
                        endAngle: startAngle,
                        clockwise: false)
            path.close()

            remainingColor.setFill()
            path.fill()
        }

        // Completed segments will be drawn by animation layer
    }
}
