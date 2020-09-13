{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RecursiveDo     #-}

-- TODO move out of Reflex folder
module Potato.Flow.Reflex.Everything (
  KeyboardData(..)
  , KeyboardKey(..)
  , KeyboardKeyType(..)

  , MouseModifier(..)
  , MouseButton(..)
  , MouseDragState(..)
  , LMouseData(..)
  , MouseStart(..)
  , MouseDrag(..)
  , newDrag
  , continueDrag

  , Tool(..)
  , LayerDisplay(..)
  , MouseManipulator(..)
  , Selection
  , disjointUnionSelection
  , EverythingFrontend(..)
  , EverythingBackend(..)
  , emptyEverythingFrontend
  , emptyEverythingBackend
  , EverythingCombined_DEBUG(..)
  , combineEverything

) where

import           Relude

import           Potato.Flow.BroadPhase
import           Potato.Flow.Math
import           Potato.Flow.SEltMethods
import           Potato.Flow.SElts
import           Potato.Flow.Types

-- erhm, maybe move PFEventTag to somewhere else? Could just duplicate it in this file
import           Potato.Flow.Reflex.Entry (PFEventTag)

import           Control.Exception        (assert)
import           Data.Dependent.Sum       (DSum ((:=>)), (==>))
import qualified Data.List                as L
import qualified Data.Sequence            as Seq

-- KEYBOARD
-- TODO decide if text input happens here or in front end
-- (don't wanna implement my own text zipper D:)
data KeyboardData = KeyboardData KeyboardKey KeyboardKeyType

data KeyboardKey =
  KeyboardKey_Esc
  | KeyboardKey_Return
  | KeyboardKey_Space
  | KeyboardKey_Char Char

data KeyboardKeyType =
  KeyboardKeyType_Down
  | KeyboardKeyType_Up
  | KeyboardKeyType_Click

-- MOUSE
-- TODO move all this stuff to types folder or something
-- only ones we care about
data MouseModifier = MouseModifier_Shift | MouseModifier_Alt

data MouseButton = MouseButton_Left | MouseButton_Middle | MouseButton_Right

data MouseDragState = MouseDragState_Down | MouseDragState_Dragging | MouseDragState_Up

-- TODO is this the all encompassing mouse event we want?
-- only one modifier allowed at a time for our app
-- TODO is there a way to optionally support more fidelity here?
-- mouse drags are sent as click streams
data LMouseData = LMouseData {
  _lMouseData_position    :: XY
  , _lMouseData_isRelease :: Bool
  , _lMouseData_button    :: MouseButton
}

data MouseStart = MouseStart {
  _mouseStart_from          :: XY
  , _mouseStart_startButton :: MouseButton
}

data MouseDrag = MouseDrag {
  _mouseDrag_start   :: MouseStart
  -- likely not needed as they will be in the input event
  , _mouseDrag_to    :: XY
  , _mouseDrag_state :: MouseDragState
}

newDrag :: LMouseData -> MouseDrag
newDrag LMouseData {..} = assert (not _lMouseData_isRelease) $ MouseDrag {
    _mouseDrag_start = MouseStart _lMouseData_position _lMouseData_button
    , _mouseDrag_to = _lMouseData_position
    , _mouseDrag_state = MouseDragState_Down
  }

continueDrag :: LMouseData -> MouseStart -> MouseDrag
continueDrag LMouseData {..} ms = MouseDrag {
    _mouseDrag_start = ms
    , _mouseDrag_to = _lMouseData_position
    , _mouseDrag_state = if _lMouseData_isRelease
      then MouseDragState_Up
      else MouseDragState_Dragging
  }


-- TOOL
data Tool = Tool_Select | Tool_Pan | Tool_Box | Tool_Line | Tool_Text deriving (Eq, Show, Enum)

-- LAYER
data LayerDisplay = LayerDisplay {
  _layerDisplay_isFolder :: Bool
  , _layerDisplay_name   :: Text
  , _layerDisplay_ident  :: Int
  -- TODO hidden/locked states
  -- TODO reverse mapping to selt
}

-- SELECTION
type Selection = Seq SuperSEltLabel

-- TODO move to its own file
-- selection helpers
disjointUnion :: (Eq a) => [a] -> [a] -> [a]
disjointUnion a b = L.union a b L.\\ L.intersect a b

-- TODO real implementation...
disjointUnionSelection :: Selection -> Selection -> Selection
disjointUnionSelection s1 s2 = Seq.fromList $ disjointUnion (toList s1) (toList s2)

data SelectionManipulatorType = SMTNone | SMTBox | SMTLine | SMTText | SMTBoundingBox deriving (Show, Eq)

computeSelectionType :: Selection -> SelectionManipulatorType
computeSelectionType = foldl' foldfn SMTNone where
  foldfn accType (_,_,SEltLabel _ selt) = case accType of
    SMTNone -> case selt of
      SEltBox _  -> SMTBox
      SEltLine _ -> SMTLine
      SEltText _ -> SMTText
      _          -> SMTNone
    _ -> SMTBoundingBox


-- MANIPULATORS
data MouseManipulatorType = MouseManipulatorType_Corner | MouseManipulatorType_Point
data MouseManipulatorState = MouseManipulatorState_Normal | MouseManipulatorState_Dragging

data MouseManipulator = MouseManipulator {
  _mouseManipulator_pos     :: XY
  , _mouseManipulator_type  :: MouseManipulatorType
  , _mouseManipulator_state :: MouseManipulatorState
  -- back reference to object being manipulated?
  -- or just use a function
}


-- REDUCERS/REDUCER HELPERS
toMouseManipulators :: Selection -> [MouseManipulator]
toMouseManipulators selection = if Seq.length selection > 1
  then
    case Seq.lookup 0 selection of
      Nothing -> []
      Just (rid, _, SEltLabel _ selt) -> case selt of
        SEltBox SBox {..}   -> undefined
          -- _sBox_box
        SEltLine SLine {..} -> undefined
          --_sLine_start
          --_sLine_end
        SEltText SText {..} -> undefined
          --_sText_box
          --_sText_text
        _                   -> []
  else bb where
    fmapfn (rid, _, seltl) = do
      box <- getSEltBox . _sEltLabel_sElt $ seltl
      return (rid, box)
    msboxes = sequence $ fmap fmapfn selection
    bb = undefined

changeSelection :: Selection -> EverythingBackend -> EverythingBackend
changeSelection newSelection everything@EverythingBackend {..} = everything {
    _everythingBackend_selection = newSelection
    , _everythingBackend_manipulators = toMouseManipulators newSelection
  }

-- first pass processing inputs
data EverythingFrontend = EverythingFrontend {
  _everythingFrontend_selectedTool :: Tool
  , _everythingFrontend_pan        :: XY -- panPos is position of upper left corner of canvas relative to screen
  , _everythingFrontend_mouseStart :: Maybe MouseStart -- last mouse dragging state
  , _everythingFrontend_command    :: Maybe PFEventTag
}

-- second pass, taking outputs from PFOutput
data EverythingBackend = EverythingBackend {
  _everythingBackend_selection      :: Selection
  , _everythingBackend_layers       :: Seq LayerDisplay
  , _everythingBackend_manipulators :: [MouseManipulator]
  , _everythingBackend_broadPhase   :: BPTree
}

emptyEverythingFrontend :: EverythingFrontend
emptyEverythingFrontend = EverythingFrontend {
    _everythingFrontend_selectedTool   = Tool_Select
    , _everythingFrontend_pan          = V2 0 0
    , _everythingFrontend_mouseStart = Nothing
    , _everythingFrontend_command = Nothing
  }

emptyEverythingBackend :: EverythingBackend
emptyEverythingBackend = EverythingBackend {
    _everythingBackend_selection    = Seq.empty
    , _everythingBackend_layers       = Seq.empty
    , _everythingBackend_manipulators = []
    , _everythingBackend_broadPhase   = emptyBPTree
  }

-- easy output for testing
data EverythingCombined_DEBUG = EverythingCombined_DEBUG {
  _everythingCombined_selectedTool   :: Tool
  , _everythingCombined_pan          :: XY -- panPos is position of upper left corner of canvas relative to screen
  , _everythingCombined_mouseStart   :: Maybe MouseStart -- last mouse dragging state
  , _everythingCombined_command      :: Maybe PFEventTag
  , _everythingCombined_selection    :: Selection
  , _everythingCombined_layers       :: Seq LayerDisplay
  , _everythingCombined_manipulators :: [MouseManipulator]
  , _everythingCombined_broadPhase   :: BPTree
}

combineEverything :: EverythingFrontend -> EverythingBackend -> EverythingCombined_DEBUG
combineEverything EverythingFrontend {..} EverythingBackend {..} = EverythingCombined_DEBUG {
    _everythingCombined_selectedTool =   _everythingFrontend_selectedTool
    , _everythingCombined_pan        = _everythingFrontend_pan
    , _everythingCombined_mouseStart = _everythingFrontend_mouseStart
    , _everythingCombined_command    = _everythingFrontend_command
    , _everythingCombined_selection      = _everythingBackend_selection
    , _everythingCombined_layers       = _everythingBackend_layers
    , _everythingCombined_manipulators = _everythingBackend_manipulators
    , _everythingCombined_broadPhase   = _everythingBackend_broadPhase
  }
