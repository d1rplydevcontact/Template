local REQUIRED_MODULE = require(script.Parent._Index["coatmol_signalplus@3.3.1"]["signalplus"])
export type Connection = REQUIRED_MODULE.Connection 
export type Signal<Parameters...> = REQUIRED_MODULE.Signal<Parameters...>
return REQUIRED_MODULE
