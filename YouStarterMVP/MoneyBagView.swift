// MoneyBagView.swift
// YouStarterMVP

import UIKit

class MoneyBagView: UIView {

    var targetAmount: Int = 1 {
        didSet { setNeedsDisplay(); updateLabels() }
    }
    var currentAmount: Int = 0 {
        didSet { setNeedsDisplay(); updateLabels() }
    }

    private let amountLabel: UILabel
    private let targetLabel: UILabel

    override init(frame: CGRect) {
        amountLabel = UILabel()
        targetLabel = UILabel()
        super.init(frame: frame)
        setupLabels()
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        amountLabel = UILabel()
        targetLabel = UILabel()
        super.init(coder: coder)
        setupLabels()
        backgroundColor = .clear
    }

    private func setupLabels() {
        amountLabel.textAlignment = .center
        amountLabel.font = UIFont.boldSystemFont(ofSize: 24)
        amountLabel.textColor = .black
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(amountLabel)

        targetLabel.textAlignment = .center
        targetLabel.font = UIFont.systemFont(ofSize: 16)
        targetLabel.textColor = .darkGray
        targetLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(targetLabel)

        NSLayoutConstraint.activate([
            amountLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -15),
            targetLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            targetLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 5)
        ])
        updateLabels()
    }

    private func updateLabels() {
        let currentFormatted = LanguageManager.shared.formatCurrency(yenAmount: currentAmount)
        let targetFormatted = LanguageManager.shared.formatCurrency(yenAmount: targetAmount)
        
        amountLabel.text = currentFormatted
        targetLabel.text = "\(LanguageManager.shared.localizedString(for: "target")): \(targetFormatted)"
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let bagWidth: CGFloat = bounds.width * 0.8
        let bagHeight: CGFloat = bounds.height * 0.7
        let bagX = (bounds.width - bagWidth) / 2
        let bagY = bounds.height - bagHeight - 10 // Offset from bottom

        let cornerRadius: CGFloat = 20

        // Draw the empty bag outline
        let emptyBagPath = UIBezierPath(roundedRect: CGRect(x: bagX, y: bagY, width: bagWidth, height: bagHeight), cornerRadius: cornerRadius)
        UIColor.lightGray.setStroke()
        emptyBagPath.lineWidth = 2
        emptyBagPath.stroke()

        // Draw the filled portion of the bag
        let fillRatio = CGFloat(currentAmount) / CGFloat(targetAmount)
        let filledHeight = bagHeight * min(max(0, fillRatio), 1)
        let filledY = bagY + (bagHeight - filledHeight)

        let filledBagPath = UIBezierPath(roundedRect: CGRect(x: bagX, y: filledY, width: bagWidth, height: filledHeight), cornerRadius: cornerRadius)
        UIColor.systemGreen.setFill()
        filledBagPath.fill()

        // Draw the top opening of the bag
        let topOpeningPath = UIBezierPath()
        topOpeningPath.move(to: CGPoint(x: bagX, y: bagY))
        topOpeningPath.addLine(to: CGPoint(x: bagX + bagWidth, y: bagY))
        topOpeningPath.lineWidth = 2
        UIColor.lightGray.setStroke()
        topOpeningPath.stroke()
    }
}
