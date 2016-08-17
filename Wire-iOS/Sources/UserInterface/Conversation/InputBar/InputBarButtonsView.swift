//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//


import Foundation
import Cartography

private struct InputBarRowConstants {
    let titleTopMargin: CGFloat = 10
    let minimumButtonWidthIPhone5: CGFloat = 53
    let minimumButtonWidth: CGFloat = 56
    let buttonsBarHeight: CGFloat = 56
    let contentLeftMargin = WAZUIMagic.cgFloatForIdentifier("content.left_margin")
    let contentRightMargin = WAZUIMagic.cgFloatForIdentifier("content.right_margin")
    let iconSize = UIImage.sizeForZetaIconSize(.Tiny)
    let buttonMargin = WAZUIMagic.cgFloatForIdentifier("content.left_margin") / 2 - UIImage.sizeForZetaIconSize(.Tiny) / 2
    
    private let screenWidthIPhone5: CGFloat = 320
    
    func minimumButtonWidth(forWidth width: CGFloat) -> CGFloat {
        return width <= screenWidthIPhone5 ? minimumButtonWidthIPhone5 : minimumButtonWidth
    }
}


public final class InputBarButtonsView: UIView {
    
    typealias RowIndex = UInt
    
    private(set) var multilineLayout: Bool = false
    private(set) var currentRow: RowIndex = 0
    
    private var buttonRowTopInset: NSLayoutConstraint!
    private var buttonRowHeight: NSLayoutConstraint!
    private var lastLayoutWidth: CGFloat = 0
    
    private let expandRowButton = IconButton()
    private let buttons: [UIButton]
    private let buttonContainer = UIView()
    private let constants = InputBarRowConstants()
    
    required public init(buttons: [UIButton]) {
        self.buttons = buttons
        super.init(frame: CGRectZero)
        configureViews()
        createConstraints()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureViews() {
        addSubview(buttonContainer)
        
        buttons.forEach {
            $0.addTarget(self, action: #selector(anyButtonPressed), forControlEvents: .TouchUpInside)
            buttonContainer.addSubview($0)
        }
        
        buttonContainer.clipsToBounds = true
        expandRowButton.accessibilityIdentifier = "showOtherRowButton"
        expandRowButton.setIcon(.Elipsis, withSize: .Tiny, forState: .Normal)
        expandRowButton.addTarget(self, action: #selector(elipsisButtonPressed), forControlEvents: .TouchUpInside)
        addSubview(expandRowButton)
    }
    
    func createConstraints() {
        constrain(self, buttonContainer)  { view, buttonRow in
            self.buttonRowTopInset = view.top == buttonRow.top
            buttonRow.left == view.left
            buttonRow.right == view.right
            buttonRowHeight = buttonRow.height == 0
            view.height == constants.buttonsBarHeight
            view.width == 414 ~ 750
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size.width != lastLayoutWidth else { return }
        layoutAndConstrainButtonRows()
        lastLayoutWidth = bounds.size.width
    }
    
    
    func showRow(rowIndex: RowIndex, animated: Bool) {
        guard rowIndex != currentRow else { return }
        currentRow = rowIndex
        buttonRowTopInset.constant = CGFloat(rowIndex) * constants.buttonsBarHeight
        UIView.wr_animateWithEasing(RBBEasingFunctionEaseInOutExpo, duration: animated ? 0.35 : 0, animations: layoutIfNeeded)
    }
    
    // MARK: - Button Layout
    
    private func layoutAndConstrainButtonRows() {
        guard bounds.size.width > 0 else { return }
        
        // Drop existing constraints
        buttons.forEach {
            $0.removeFromSuperview()
            buttonContainer.addSubview($0)
        }
        
        let minButtonWidth = constants.minimumButtonWidth(forWidth: bounds.width)
        let numberOfButtons = Int(floorf(Float(bounds.width / minButtonWidth)))
        multilineLayout = numberOfButtons < buttons.count
        
        let (firstRow, secondRow): ([UIButton], [UIButton])
        let customButtonCount = numberOfButtons - 1 // Last one is alway the expand button
        
        if multilineLayout {
            firstRow = buttons.prefix(customButtonCount) + [expandRowButton]
            secondRow = Array<UIButton>(buttons.suffix(buttons.count - customButtonCount))
            buttonRowHeight.constant = constants.buttonsBarHeight * 2
        } else {
            firstRow = buttons
            secondRow = []
            buttonRowHeight.constant = constants.buttonsBarHeight
        }
        
        constrainRowOfButtons(firstRow, inset: 0, rowIsFull: true, referenceButton: .None)
        
        guard !secondRow.isEmpty else { return }
        let filled = secondRow.count == numberOfButtons
        constrainRowOfButtons(secondRow, inset: constants.buttonsBarHeight, rowIsFull: filled, referenceButton: firstRow[1])
    }
    
    private func constrainRowOfButtons(buttons: [UIButton], inset: CGFloat, rowIsFull: Bool, referenceButton: UIButton?) {
        constrain(buttons.first!) { firstButton in
            firstButton.leading == firstButton.superview!.leading
        }
        
        if rowIsFull {
            constrain(buttons.last!) { lastButton in
                lastButton.trailing == lastButton.superview!.trailing
            }
        }
        
        for button in buttons {
            if button == expandRowButton {
                constrain(button, self) { button, view in
                    button.top == view.top
                    button.height == constants.buttonsBarHeight
                }
            } else {
                constrain(button, buttonContainer) { button, container in
                    button.top == container.top + inset
                    button.height == constants.buttonsBarHeight
                }
            }
        }
        
        var previous = buttons.first!
        for current in buttons.dropFirst() {
            let isFirstButton = previous == buttons.first
            let isLastButton = rowIsFull && current == buttons.last
            
            constrain(previous, current) { previous, current in
                previous.trailing == current.leading
                
                if (isFirstButton) {
                    previous.width == current.width * 0.5 + constants.iconSize / 2 + constants.buttonMargin
                } else if (isLastButton) {
                    current.width == previous.width * 0.5 + constants.iconSize / 2 + constants.buttonMargin
                } else {
                    current.width == previous.width
                }
            }
            previous = current
        }
        
        if let reference = referenceButton where !rowIsFull {
            constrain(reference, buttons.last!) { reference, lastButton in
                lastButton.width == reference.width
            }
        }
        
        setupInsets(forButtons: buttons, rowIsFull: rowIsFull)
    }
    
    private func setupInsets(forButtons buttons: [UIButton], rowIsFull: Bool) {
        let firstButton = buttons.first!
        let firstButtonLabelSize = firstButton.titleLabel!.intrinsicContentSize()
        let firstTitleMargin = (constants.contentLeftMargin / 2) - constants.iconSize - (firstButtonLabelSize.width / 2)
        firstButton.contentHorizontalAlignment = .Left
        firstButton.imageEdgeInsets = UIEdgeInsetsMake(0, constants.buttonMargin, 0, 0)
        firstButton.titleEdgeInsets = UIEdgeInsetsMake(constants.iconSize + firstButtonLabelSize.height + constants.titleTopMargin, firstTitleMargin, 0, 0)
        
        if rowIsFull {
            let lastButton = buttons.last!
            let lastButtonLabelSize = lastButton.titleLabel!.intrinsicContentSize()
            let lastTitleMargin = constants.contentLeftMargin / 2.0 - lastButtonLabelSize.width / 2.0
            lastButton.contentHorizontalAlignment = .Right
            lastButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, constants.buttonMargin - lastButtonLabelSize.width)
            lastButton.titleEdgeInsets = UIEdgeInsetsMake(constants.iconSize + lastButtonLabelSize.height + constants.titleTopMargin, 0, 0, lastTitleMargin - 1)
            lastButton.titleLabel?.lineBreakMode = .ByClipping
        }
        
        for button in buttons.dropFirst().dropLast() {
            let buttonLabelSize = button.titleLabel!.intrinsicContentSize()
            button.contentHorizontalAlignment = .Center
            button.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, -buttonLabelSize.width)
            button.titleEdgeInsets = UIEdgeInsetsMake(constants.iconSize + buttonLabelSize.height + constants.titleTopMargin, -constants.iconSize, 0, 0)
        }
    }
    
}

extension InputBarButtonsView {
    @objc private func anyButtonPressed(button: UIButton!) {
        showRow(0, animated: true)
    }
    
    @objc private func elipsisButtonPressed(button: UIButton!) {
        showRow(currentRow == 0 ? 1 : 0, animated: true)
    }
}