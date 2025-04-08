//
//  RendererManager.swift
//  VidyoConnector-iOS
//
//  Created by Artem Dyavil on 26.05.2023.
//

import NgrPlugin
import VidyoClientIOS
import DevicePpi

class RendererManager {
    static let shared = RendererManager()
    private let connector = ConnectorManager.shared.connector

    init() {
    }

    public func hideView(_ view: inout UIView) {
        connector.hideView(&view)
    }
    
    func showConferenceView(_ view: inout UIView) {
        var viewStyle = VCConnectorViewStyle.default
        switch DefaultValuesManager.shared.renderer {
        case .primary:
            viewStyle = VCConnectorViewStyle.default
        case .tile:
            viewStyle = VCConnectorViewStyle.tiles
        case .ngr:
            viewStyle = DefaultValuesManager.shared.layout == .grid ? VCConnectorViewStyle.ngrGrid : VCConnectorViewStyle.ngrSpeaker
        default:
            return
        }
        connector.assignView(toCompositeRenderer: &view, viewStyle: viewStyle, remoteParticipants: ConnectorManager.shared.participantsNumber)
        
        setLabelVisible(&view, DefaultValuesManager.shared.labelVisibility);
        setAudioMeterVisible(&view, DefaultValuesManager.shared.audioMeterVisibility);
        setDebugInfoVisible(view, DefaultValuesManager.shared.debugInfoVisibility);
        setPreviewMirroringEnable(&view, DefaultValuesManager.shared.previewMirroring);
        setShowAudioTilesEnable(&view, DefaultValuesManager.shared.showAudioTiles);
        setExpandedCameraControlEnable(&view, DefaultValuesManager.shared.expandedCameraControl);
        setPixelDensity(&view, getDevicePpi(viewStyle));
        setViewingDistance(&view, 1.0);
        setFeccIconCustomLayout(&view, DefaultValuesManager.shared.feccIconCustomLayout);
        setVerticalVideoCentering(&view, DefaultValuesManager.shared.verticalVideoCentering);
        
        var selectedSelfViewOption = ""
        for optionToChoose in GeneralSettingsOption.options.selfView {
              if(optionToChoose.isChosen == true) {
                  selectedSelfViewOption = optionToChoose.title
              }
         }
        setPreviewPosition(&view, selectedSelfViewOption);
        
        var selectedBorderStyle = ""
        for optionToChoose in GeneralSettingsOption.options.borderStyle {
              if(optionToChoose.isChosen == true) {
                  selectedBorderStyle = optionToChoose.title
              }
         }
        setBorderStyle(&view, selectedBorderStyle);
    }
    
    func showPreviewView(_ view: inout UIView) {
        var viewStyle = VCConnectorViewStyle.default
        switch DefaultValuesManager.shared.renderer {
        case .primary:
            viewStyle = VCConnectorViewStyle.default
        case .tile:
            viewStyle = VCConnectorViewStyle.tiles
        case .ngr:
            viewStyle = DefaultValuesManager.shared.layout == .grid ? VCConnectorViewStyle.ngrGrid : VCConnectorViewStyle.ngrSpeaker
        default:
            return
        }
        connector.assignView(toCompositeRenderer: &view, viewStyle: viewStyle, remoteParticipants: 0)
        setLabelVisible(&view, DefaultValuesManager.shared.labelVisibility);
        setAudioMeterVisible(&view, DefaultValuesManager.shared.audioMeterVisibility);
    }
    
    func setViewSize(_ view: inout UIView, _ rect: CGRect) {
        connector.showView(at: &view, x: 0, y: 0, width: UInt32(rect.size.width), height: UInt32(rect.size.height))
    }
    
    func pinParticipant(_ participant: VCParticipant, _ pin: Bool, _ callback: @escaping (Bool) -> Void) {
        let ret = connector.pinParticipant(participant, pin: pin)
        callback(ret)
    }
    
    func handleGestureEvent(_ view: UIView, _ type: UITouch.Phase, _ eventId: Int, _ pos: CGPoint) {
    }
    
    public func setLabelVisible(_ view: inout UIView, _ visible: Bool) {
        connector.showViewLabel(&view, showLabel: visible)
    }
    
    public func setAudioMeterVisible(_ view: inout UIView, _ visible: Bool) {
        connector.showAudioMeters(&view, showMeters: visible)
    }
    
    public func setDebugInfoVisible(_ view: UIView, _ visible: Bool) {
        if visible == true {
            connector.enableDebug(0, logFilter: "")
        }
        else {
            connector.disableDebug()
        }
    }
    
    public func setPreviewMirroringEnable(_ view: inout UIView, _ enable: Bool) {
        struct PreviewMirroring {
            let value: Bool

            func toJSONString() -> String {
                return "{\"EnablePreviewMirroring\": \(value)}"
            }
        }
        
        let enable = PreviewMirroring(value: enable);
        connector.setRendererOptionsForViewId(&view, options: enable.toJSONString());
    }
    
    public func setShowAudioTilesEnable(_ view: inout UIView, _ enable: Bool) {
        struct ShowAudioTiles {
            let value: Bool

            func toJSONString() -> String {
                return "{\"ShowAudioTiles\": \(value)}"
            }
        }
        
        let enable = ShowAudioTiles(value: enable);
        connector.setRendererOptionsForViewId(&view, options: enable.toJSONString());
    }
    
    public func setExpandedCameraControlEnable(_ view: inout UIView, _ enable: Bool) {
        struct Control {
            let value: Bool

            func toJSONString() -> String {
                return "{\"EnableExpandedCameraControl\": \(value)}"
            }
        }
        
        let enable = Control(value: enable);
        connector.setRendererOptionsForViewId(&view, options: enable.toJSONString());
    }
    
    public func setPreviewPosition(_ view: inout UIView, _ options: String) {
        
        var _x: String = "";
        var _y: String = "";

        switch options {
            case "Top Left":
                _x = "PipPositionLeft"
                _y = "PipPositionTop";
            break;
            
            case "Bottom Right":
                _x = "PipPositionRight";
                _y = "PipPositionBottom";
            break;
            
            case "Bottom Left":
                _x = "PipPositionLeft";
                _y = "PipPositionBottom";
                
            break;
            
            case "Top Right":
                _x = "PipPositionRight";
                _y = "PipPositionTop";
            break;
            
            case "Center Right":
                _x = "PipPositionRight";
                _y = "PipPositionCenter";
            break;
            
            case "Center Left":
                _x = "PipPositionLeft";
                _y = "PipPositionCenter";
            break;
            
            case "Top Center":
                _x = "PipPositionCenter";
                _y = "PipPositionTop";
            break;

            case "Center Center":
                _x = "PipPositionCenter";
                _y = "PipPositionCenter";
            break;
            
            case "Bottom Center":
                _x = "PipPositionCenter";
                _y = "PipPositionBottom";
            break;

            default:
                _x = "PipPositionRight";
                _y = "PipPositionTop";
            break;
        }
        
        struct SetPipPosition {
            let x: String
            let y: String

            func toJSONString() -> String {
                return """
                {
                    "SetPipPosition": {
                        "x": "\(x)",
                        "y": "\(y)"
                    }
                }
                """
            }
        }

        let position = SetPipPosition(x: _x, y: _y)
        connector.setRendererOptionsForViewId(&view, options: position.toJSONString());
    }

    func getDevicePpi(_ viewStyle: VCConnectorViewStyle) -> Double{
        var ppi: Double = 0.0
        if (VCConnectorViewStyle.tiles == viewStyle || VCConnectorViewStyle.default == viewStyle){
            ppi = {
                switch Ppi.get() {
                case .success(let ppi):
                    return ppi
                case .unknown(let bestGuessPpi, _):
                    // A bestGuessPpi value is provided but may be incorrect
                    // Treat as a non-fatal error -- e.g. log to your backend and/or display a message
                    return bestGuessPpi
                }
            }()
        } else {
            ppi = 1.0
        }
        return ppi;
    }

    public func setPixelDensity(_ view: inout UIView, _ ppi: Double) {
        struct Control {
            let value: Double
            
            func toJSONString() -> String {
                return "{\"SetPixelDensity\": \(value)}"
            }
        }
        
        let ppi = Control(value: ppi);
        connector.setRendererOptionsForViewId(&view, options: ppi.toJSONString());
    }
    
    public func setBorderStyle(_ view: inout UIView, _ options: String) {
        
        struct BorderStyle {
            let value: String

            func toJSONString() -> String {
                return "{\"BorderStyle\": \"\(value)\"}"
            }
        }

        let style = BorderStyle(value: options);
        connector.setRendererOptionsForViewId(&view, options: style.toJSONString());
    }
    
    public func setFeccIconCustomLayout(_ view: inout UIView, _ enable: Bool) {
        struct layout {
            let value: Bool

            func toJSONString() -> String {
                return "{\"EnableFECCIconCustomLayout\": \(value)}"
            }
        }
        
        let enable = layout(value: enable);
        connector.setRendererOptionsForViewId(&view, options: enable.toJSONString());
    }
    
    public func setVerticalVideoCentering(_ view: inout UIView, _ enable: Bool) {
        struct centering {
            let value: Bool

            func toJSONString() -> String {
                return "{\"EnableVerticalVideoCentering\": \(value)}"
            }
        }
        
        let enable = centering(value: enable);
        connector.setRendererOptionsForViewId(&view, options: enable.toJSONString());
    }

    public func setViewingDistance(_ view: inout UIView, _ distance: Double) {
        struct Distance {
            let value: Double

            func toJSONString() -> String {
                return "{\"ViewingDistance\": \(value)}"
            }
        }

        let distance = Distance(value: distance);
        connector.setRendererOptionsForViewId(&view, options: distance.toJSONString());
    }
}
