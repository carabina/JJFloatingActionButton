
import UIKit
import SnapKit

@objc public enum JJFloatingActionButtonState: Int {
    case closed
    case open
    case opening
    case closing
}

@objc public protocol JJFloatingActionButtonDelegate {
    @objc optional func floatingActionButtonWillOpen(_ button: JJFloatingActionButton)
    @objc optional func floatingActionButtonDidOpen(_ button: JJFloatingActionButton)
    @objc optional func floatingActionButtonWillClose(_ button: JJFloatingActionButton)
    @objc optional func floatingActionButtonDidClose(_ button: JJFloatingActionButton)
}

@objc public class JJFloatingActionButton: UIView {

    @objc public var delegate: JJFloatingActionButtonDelegate?

    @objc public var items: [JJActionItem] = [] {
        didSet {
            items.forEach { item in
                configureItem(item)
            }
            configureButton()
        }
    }

    @objc public var buttonColor = UIColor(hue: 0.31, saturation: 0.37, brightness: 0.76, alpha: 1.00) {
        didSet {
            buttonView.circleColor = buttonColor
        }
    }

    @objc public var defaultButtonImage: UIImage? {
        didSet {
            configureButton()
        }
    }

    @objc public var buttonImageColor = UIColor.white {
        didSet {
            buttonView.imageColor = buttonImageColor
        }
    }

    @objc public var shadowColor = UIColor.black {
        didSet {
            self.buttonView.layer.shadowColor = shadowColor.cgColor
        }
    }

    @objc public var shadowOffset = CGSize(width: 0, height: 1) {
        didSet {
            self.buttonView.layer.shadowOffset = shadowOffset
        }
    }

    @objc public var shadowOpacity = Float(0.4) {
        didSet {
            self.buttonView.layer.shadowOpacity = shadowOpacity
        }
    }

    @objc public var shadowRadius = CGFloat(2) {
        didSet {
            self.buttonView.layer.shadowRadius = shadowRadius
        }
    }

    @objc public var overlayColor = UIColor(white: 0, alpha: 0.5) {
        didSet {
            overlayView.backgroundColor = overlayColor
        }
    }

    @objc public var itemTitleFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)

    @objc public var itemButtonColor = UIColor.white

    @objc public var itemImageColor = UIColor(hue: 0.31, saturation: 0.37, brightness: 0.76, alpha: 1.00)

    @objc public var itemTitleColor = UIColor.white

    @objc public var itemShadowColor = UIColor.black

    @objc public var itemShadowOffset = CGSize(width: 0, height: 1)

    @objc public var itemShadowOpacity = Float(0.4)

    @objc public var itemShadowRadius = CGFloat(2)

    @objc public var itemSizeRatio = CGFloat(0.75)

    @objc public var interItemSpacing = CGFloat(12)

    @objc public var rotationAngle = -CGFloat.pi / 4

    @objc public fileprivate(set) var state: JJFloatingActionButtonState = .closed

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    fileprivate lazy var buttonView: JJCircleImageView = defaultButtonView()

    fileprivate lazy var overlayView: UIControl = defaultOverlayView()

    fileprivate var openItems: [JJActionItem]?
}

public extension JJFloatingActionButton {
    public override var intrinsicContentSize: CGSize {
        return CGSize(width: 56, height: 56)
    }
}

public extension JJFloatingActionButton {
    @objc @discardableResult public func addItem(title: String?, image: UIImage?, action: ((JJActionItem) -> Void)?) -> JJActionItem {
        let item = JJActionItem()
        item.title = title
        item.image = image
        item.action = action

        items.append(item)
        configureItem(item)
        configureButton()

        return item
    }

    @objc public func open(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard state == .closed else {
            return
        }
        guard let superview = self.superview else {
            return
        }
        state = .opening
        delegate?.floatingActionButtonWillOpen?(self)
        overlayView.isEnabled = true

        superview.bringSubview(toFront: self)
        superview.insertSubview(overlayView, belowSubview: self)
        overlayView.snp.makeConstraints { make in
            make.edges.equalTo(superview)
        }

        var previousItem: JJActionItem?
        for item in items {
            if item.isHidden {
                continue
            }
            item.alpha = 0
            item.transform = .identity
            insertSubview(item, belowSubview: buttonView)
            item.snp.makeConstraints { make in
                let previousView = previousItem ?? buttonView
                make.height.equalTo(buttonView).multipliedBy(itemSizeRatio)
                make.bottom.equalTo(previousView.snp.top).offset(-interItemSpacing)
            }
            item.circleView.snp.makeConstraints { make in
                make.centerX.equalTo(buttonView)
            }
            previousItem = item
        }
        openItems = items

        setNeedsLayout()
        layoutIfNeeded()

        let animationGroup = DispatchGroup()

        let buttonAnimation: () -> Void = {
            self.overlayView.alpha = 1
            self.buttonView.transform = CGAffineTransform(rotationAngle: self.rotationAngle)
        }
        animate(duration: 0.3,
                usingSpringWithDamping: 0.55,
                initialSpringVelocity: 0.3,
                animations: buttonAnimation,
                group: animationGroup,
                animated: animated)

        var delay = 0.0
        for item in items {
            shrink(item)
            let itemAnimation: () -> Void = {
                item.transform = .identity
                item.alpha = 1
            }
            animate(duration: 0.3,
                    delay: delay,
                    usingSpringWithDamping: 0.55,
                    initialSpringVelocity: 0.3,
                    animations: itemAnimation,
                    group: animationGroup,
                    animated: animated)

            delay += 0.1
        }

        animationGroup.notify(queue: .main) {
            self.state = .open
            self.delegate?.floatingActionButtonDidOpen?(self)
            completion?()
        }
    }

    @objc public func close(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard state == .open else {
            return
        }
        state = .closing
        delegate?.floatingActionButtonWillClose?(self)
        overlayView.isEnabled = false

        let animationGroup = DispatchGroup()

        let buttonAnimations: () -> Void = {
            self.overlayView.alpha = 0
            self.buttonView.transform = CGAffineTransform(rotationAngle: 0)
        }
        let buttonAnimationCompletion: (Bool) -> Void = { _ in
            self.overlayView.removeFromSuperview()
        }
        animate(duration: 0.3,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.8,
                animations: buttonAnimations,
                completion: buttonAnimationCompletion,
                animated: animated)

        var delay = 0.0
        for item in items.reversed() {
            let itemAnimation: () -> Void = {
                self.shrink(item)
                item.alpha = 0
            }
            let itemAnimationCompletion: (Bool) -> Void = { _ in
                item.removeFromSuperview()
            }
            animate(duration: 0.15,
                    delay: delay,
                    usingSpringWithDamping: 0.6,
                    initialSpringVelocity: 0.8,
                    animations: itemAnimation,
                    completion: itemAnimationCompletion,
                    group: animationGroup,
                    animated: animated)

            delay += 0.1
        }

        animationGroup.notify(queue: .main) {
            self.openItems = nil
            self.state = .closed
            self.delegate?.floatingActionButtonDidClose?(self)
            completion?()
        }
    }
}

fileprivate extension JJFloatingActionButton {
    func setup() {
        backgroundColor = UIColor.clear
        clipsToBounds = false

        addSubview(buttonView)
        buttonView.snp.makeConstraints { make in
            make.center.equalTo(self)
            make.width.equalTo(buttonView.snp.height)
            make.size.lessThanOrEqualTo(self)
            make.size.equalTo(self).priority(.high)
        }

        configureButton()
    }

    func defaultButtonView() -> JJCircleImageView {
        let view = JJCircleImageView()
        view.circleColor = self.buttonColor
        view.imageColor = self.buttonImageColor
        view.layer.shadowColor = self.shadowColor.cgColor
        view.layer.shadowOffset = self.shadowOffset
        view.layer.shadowOpacity = self.shadowOpacity
        view.layer.shadowRadius = self.shadowRadius
        return view
    }

    func defaultOverlayView() -> UIControl {
        let control = UIControl()
        control.backgroundColor = self.overlayColor
        control.addTarget(self, action: #selector(overlayViewWasTapped), for: .touchUpInside)
        control.isUserInteractionEnabled = true
        control.isEnabled = false
        control.alpha = 0
        return control
    }

    func configureItem(_ item: JJActionItem) {
        item.circleView.circleColor = self.itemButtonColor
        item.circleView.imageColor = self.itemImageColor
        item.titleLabel.font = self.itemTitleFont
        item.titleLabel.textColor = self.itemTitleColor
        item.layer.shadowColor = self.itemShadowColor.cgColor
        item.layer.shadowOpacity = self.itemShadowOpacity
        item.layer.shadowOffset = self.itemShadowOffset
        item.layer.shadowRadius = self.itemShadowRadius
        item.delegate = self
    }

    func configureButton() {
        buttonView.image = currentButtonImage
    }

    var currentButtonImage: UIImage? {
        var image: UIImage?

        if items.count == 1 {
            image = items.first?.image
        }

        if image == nil {
            if defaultButtonImage == nil {
                defaultButtonImage = defaultButtonImageResource
            }
            image = defaultButtonImage
        }

        return image
    }

    var defaultButtonImageResource: UIImage? {
        let frameworkBundle = Bundle(for: JJFloatingActionButton.self)
        guard let resourceBundleURL = frameworkBundle.url(forResource: "JJFloatingActionButton", withExtension: "bundle") else {
            return nil
        }
        let resourceBundle = Bundle(url: resourceBundleURL)
        let image = UIImage(named: "Plus", in: resourceBundle, compatibleWith: nil)
        return image
    }

    func animate(duration: TimeInterval, delay: TimeInterval = 0, usingSpringWithDamping dampingRatio: CGFloat, initialSpringVelocity velocity: CGFloat, options _: UIViewAnimationOptions = [.beginFromCurrentState], animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil, group: DispatchGroup? = nil, animated: Bool = true) {

        let groupedAnimations: () -> Void = {
            group?.enter()
            animations()
        }
        let groupedCompletion: (Bool) -> Void = { finished in
            completion?(finished)
            group?.leave()
        }

        if animated {
            UIView.animate(withDuration: duration,
                           delay: delay,
                           usingSpringWithDamping: dampingRatio,
                           initialSpringVelocity: velocity,
                           animations: groupedAnimations,
                           completion: groupedCompletion)
        } else {
            groupedAnimations()
            groupedCompletion(true)
        }
    }

    func shrink(_ item: JJActionItem) {
        let scaleFactor = CGFloat(0.4)
        let itemWidth = item.frame.width
        let itemCircleWidth = item.circleView.frame.width
        let translationX = (itemWidth - itemCircleWidth) * (1 - scaleFactor) / 2
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let translation = CGAffineTransform(translationX: translationX, y: 0)
        let transform = scale.concatenating(translation)
        item.transform = transform
    }

    func updateHighlightedStateForTouches(_ touches: Set<UITouch>) {
        buttonView.isHighlighted = touchesAreTapInside(touches)
    }

    func touchesAreTapInside(_ touches: Set<UITouch>) -> Bool {
        guard touches.count == 1 else {
            return false
        }
        guard let touch = touches.first else {
            return false
        }
        let point = touch.location(in: self)
        guard bounds.contains(point) else {
            return false
        }

        return true
    }

    @objc func overlayViewWasTapped() {
        close()
    }

    func buttonWasTapped() {
        switch state {
        case .open:
            close()
            break

        case .closed:
            switch items.count {
            case 0:
                break

            case 1:
                let item = items.first
                item?.action?(item!)
                break

            default:
                open()
                break
            }
            break

        default:
            break
        }
    }
}

// MARK: Touches
extension JJFloatingActionButton {
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        if state == .open, let openItems = openItems {
            for item in openItems {
                if item.isHidden || !item.isUserInteractionEnabled {
                    continue
                }
                let pointInItem = item.convert(point, from: self)
                if item.bounds.contains(pointInItem) {
                    return item.hitTest(pointInItem, with: event)
                }
            }
        }
        return super.hitTest(point, with: event)
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        updateHighlightedStateForTouches(touches)
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        updateHighlightedStateForTouches(touches)
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        buttonView.isHighlighted = false
        if touchesAreTapInside(touches) {
            buttonWasTapped()
        }
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        buttonView.isHighlighted = false
    }
}

extension JJFloatingActionButton: JJActionItemDelegate {
    func actionButtonWasTapped(_ item: JJActionItem) {
        close {
            item.action?(item)
        }
    }
}
