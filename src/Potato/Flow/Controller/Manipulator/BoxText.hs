{-# LANGUAGE RecordWildCards #-}

-- TODO probably move this to Manipulator.Box.Text
module Potato.Flow.Controller.Manipulator.BoxText (
  BoxTextHandler(..)
  , BoxTextInputState(..)
  , makeBoxTextHandler

  -- exposed for testing
  , makeBoxTextInputState
  , mouseText

) where

import           Relude

import           Potato.Flow.Controller.Handler
import           Potato.Flow.Controller.Input
import           Potato.Flow.Controller.Manipulator.Common
import           Potato.Flow.Controller.Types
import           Potato.Flow.Math
import           Potato.Flow.SElts
import           Potato.Flow.Types
import           Potato.Flow.Owl
import           Potato.Flow.OwlWorkspace

import           Control.Exception
import           Data.Default
import           Data.Dependent.Sum                        (DSum ((:=>)))
import qualified Data.IntMap                               as IM
import qualified Data.Map as Map
import qualified Data.Sequence                             as Seq
import qualified Potato.Data.Text.Zipper                          as TZ
import qualified Text.Pretty.Simple as Pretty
import qualified Data.Text.Lazy as LT

getSBox :: Selection -> (REltId, SBox)
getSBox selection = case superOwl_toSElt_hack sowl of
  SEltBox sbox -> (rid, sbox)
  selt -> error $ "expected SBox, got " <> show selt
  where
    sowl = selectionToSuperOwl selection
    rid = _superOwl_id sowl

data BoxTextInputState = BoxTextInputState {
  _boxTextInputState_rid            :: REltId
  , _boxTextInputState_original     :: Text -- needed to properly create DeltaText for undo
  , _boxTextInputState_box          :: LBox -- we can always pull this from selection, but may as well store it
  , _boxTextInputState_zipper       :: TZ.TextZipper
  , _boxTextInputState_displayLines :: TZ.DisplayLines ()
  --, _boxTextInputState_selected :: Int -- WIP
} deriving (Show)

updateBoxTextInputStateWithSBox :: SBox -> BoxTextInputState -> BoxTextInputState
updateBoxTextInputStateWithSBox sbox btis = r where
  alignment = convertTextAlignToTextZipperTextAlignment . _textStyle_alignment . _sBoxText_style . _sBox_text $ sbox

  CanonicalLBox _ _ newBox@(LBox _ (V2 width' _)) = canonicalLBox_from_lBox $ _sBox_box sbox
  width = case _sBox_boxType sbox of
    SBoxType_BoxText   -> max 0 (width'-2)
    SBoxType_NoBoxText -> width'
    _                  -> error "wrong type"
  r = btis {
      _boxTextInputState_box = newBox
      , _boxTextInputState_displayLines = TZ.displayLinesWithAlignment alignment width () () (_boxTextInputState_zipper btis)
    }

-- TODO I think you need to pad empty lines in the zipper to fill out the box D:
-- ok, no you don't, that's only for the non-paragraph text area that we don't actually have yet
makeBoxTextInputState :: REltId -> SBox -> RelMouseDrag -> BoxTextInputState
makeBoxTextInputState rid sbox rmd = r where
  ogtext = _sBoxText_text . _sBox_text $ sbox
  ogtz = TZ.fromText ogtext
  r' = BoxTextInputState {
      _boxTextInputState_rid = rid
      , _boxTextInputState_original   = ogtext
      , _boxTextInputState_zipper   = ogtz

      -- these fields get updated in next pass
      , _boxTextInputState_box = error "expected to be filled"
      , _boxTextInputState_displayLines = error "expected to be filled"

      --, _boxTextInputState_selected = 0
    }
  r'' = updateBoxTextInputStateWithSBox sbox r'
  r = mouseText r'' sbox rmd

getOffset :: SBox -> XY
getOffset sbox =  case _sBox_boxType sbox of
  SBoxType_BoxText   -> V2 1 1
  SBoxType_NoBoxText -> 0
  _                  -> error "wrong type"

-- TODO define behavior for when you click outside box or assert
mouseText :: BoxTextInputState -> SBox -> RelMouseDrag -> BoxTextInputState
mouseText tais sbox rmd = r where
  RelMouseDrag MouseDrag {..} = rmd
  ogtz = _boxTextInputState_zipper tais
  CanonicalLBox _ _ (LBox (V2 x y) (V2 _ _)) = canonicalLBox_from_lBox $ _sBox_box sbox
  V2 mousex mousey = _mouseDrag_to
  V2 xoffset yoffset = getOffset sbox
  newtz = TZ.goToDisplayLinePosition (mousex-x-xoffset) (mousey-y-yoffset) (_boxTextInputState_displayLines tais) ogtz
  r = tais { _boxTextInputState_zipper = newtz }


-- TODO support shift selecting text someday meh
inputText :: BoxTextInputState -> Bool -> SuperOwl -> KeyboardKey -> (BoxTextInputState, Maybe WSEvent)
inputText tais undoFirst sowl kk = (tais { _boxTextInputState_zipper = newZip }, mop) where

  oldZip = _boxTextInputState_zipper tais
  (changed, newZip) = case kk of
    KeyboardKey_Left    -> (False, TZ.left oldZip)
    KeyboardKey_Right   -> (False, TZ.right oldZip)
    KeyboardKey_Up      -> (False, TZ.up oldZip)
    KeyboardKey_Down    -> (False, TZ.down oldZip)
    KeyboardKey_Home    -> (False, TZ.home oldZip)
    KeyboardKey_End -> (False, TZ.end oldZip)
    KeyboardKey_PageUp -> (False, TZ.pageUp 5 oldZip)
    KeyboardKey_PageDown -> (False, TZ.pageDown 5 oldZip)

    KeyboardKey_Return  -> (True, TZ.insertChar '\n' oldZip)
    KeyboardKey_Space   -> (True, TZ.insertChar ' ' oldZip)
    KeyboardKey_Delete  -> (True, TZ.deleteRight oldZip)
    KeyboardKey_Backspace -> (True, TZ.deleteLeft oldZip)
    KeyboardKey_Char c  -> (True, TZ.insertChar c oldZip)
    KeyboardKey_Paste t -> (True, TZ.insert t oldZip)

    k                   -> error $ "unexpected keyboard char (event should have been handled outside of this handler)" <> show k

  controller = CTagBoxText :=> (Identity $ CBoxText {
      _cBoxText_deltaText = (_boxTextInputState_original tais, TZ.value newZip)
    })
  mop = if changed
    then Just $ WSEManipulate (undoFirst, IM.fromList [(_superOwl_id sowl,controller)])
    else Nothing

-- TODO rename to BoxTextHandler
data BoxTextHandler = BoxTextHandler {
    -- TODO rename to active
    _boxTextHandler_isActive      :: Bool
    , _boxTextHandler_state       :: BoxTextInputState
    -- TODO you can prob delete this now, we don't persist state between sub handlers in this case
    , _boxTextHandler_prevHandler :: SomePotatoHandler
    , _boxTextHandler_undoFirst   :: Bool
  }

makeBoxTextHandler :: SomePotatoHandler -> Selection -> RelMouseDrag -> BoxTextHandler
makeBoxTextHandler prev selection rmd = BoxTextHandler {
      _boxTextHandler_isActive = False
      , _boxTextHandler_state = uncurry makeBoxTextInputState (getSBox selection) rmd
      , _boxTextHandler_prevHandler = prev
      , _boxTextHandler_undoFirst = False
    }

updateBoxTextHandlerState :: Bool -> Selection -> BoxTextHandler -> BoxTextHandler
updateBoxTextHandlerState reset selection tah@BoxTextHandler {..} = assert tzIsCorrect r where
  (_, sbox) = getSBox selection

  newText = _sBoxText_text . _sBox_text $ sbox

  recomputetz = TZ.fromText newText
  oldtz = _boxTextInputState_zipper _boxTextHandler_state
  -- NOTE that recomputetz won't have the same cursor position
  -- TODO delete this check, not very meaningful, but good for development purposes I guess
  tzIsCorrect = TZ.value oldtz == TZ.value recomputetz

  nextstate = updateBoxTextInputStateWithSBox sbox _boxTextHandler_state

  r = tah {
    _boxTextHandler_state = if reset
      then nextstate {
          _boxTextInputState_original = newText
        }
      else nextstate
    , _boxTextHandler_undoFirst = if reset
      then False
      else _boxTextHandler_undoFirst
  }

instance PotatoHandler BoxTextHandler where
  pHandlerName _ = handlerName_boxText
  pHandlerDebugShow BoxTextHandler {..} = LT.toStrict $ Pretty.pShowNoColor _boxTextHandler_state
  pHandleMouse tah' PotatoHandlerInput {..} rmd@(RelMouseDrag MouseDrag {..}) = let
      tah@BoxTextHandler {..} = updateBoxTextHandlerState False _potatoHandlerInput_selection tah'
      (_, sbox) = getSBox _potatoHandlerInput_selection
    in case _mouseDrag_state of
      MouseDragState_Down -> r where
        clickInside = does_lBox_contains_XY (_boxTextInputState_box _boxTextHandler_state) _mouseDrag_to
        newState = mouseText _boxTextHandler_state sbox rmd
        r = if clickInside
          then Just $ def {
              _potatoHandlerOutput_nextHandler = Just $ SomePotatoHandler tah {
                  _boxTextHandler_isActive = True
                  , _boxTextHandler_state = newState
                }
            }
          else Nothing

      -- TODO drag select text someday
      MouseDragState_Dragging -> Just $ captureWithNoChange tah

      MouseDragState_Up -> Just $ def {
          _potatoHandlerOutput_nextHandler = Just $ SomePotatoHandler tah {
              _boxTextHandler_isActive = False
              --, _boxTextHandler_undoFirst = False -- this variant adds new undo point each time cursor is moved
            }
        }
      MouseDragState_Cancelled -> Just $ captureWithNoChange tah

  pHandleKeyboard tah' PotatoHandlerInput {..} (KeyboardData k _) = case k of
    KeyboardKey_Esc -> Just $ def { _potatoHandlerOutput_nextHandler = Just (_boxTextHandler_prevHandler tah') }
    _ -> Just r where
      -- this regenerates displayLines unecessarily but who cares
      tah@BoxTextHandler {..} = updateBoxTextHandlerState False _potatoHandlerInput_selection tah'
      sowl = selectionToSuperOwl _potatoHandlerInput_selection

      -- TODO decide what to do with mods

      (nexttais, mev) = inputText _boxTextHandler_state _boxTextHandler_undoFirst sowl k
      r = def {
          _potatoHandlerOutput_nextHandler = Just $ SomePotatoHandler tah {
              _boxTextHandler_state  = nexttais
              , _boxTextHandler_undoFirst = case mev of
                Nothing -> _boxTextHandler_undoFirst
                --Nothing -> False -- this variant adds new undo point each time cursoer is moved
                Just _  -> True
            }
          , _potatoHandlerOutput_pFEvent = mev
        }

  pResetHandler tah PotatoHandlerInput {..} = if Seq.null (unSuperOwlParliament _potatoHandlerInput_selection)
    then Nothing -- selection was deleted or something
    else if rid /= (_boxTextInputState_rid $ _boxTextHandler_state tah)
      then Nothing -- selection was change to something else
      else case selt of
        SEltBox sbox -> if not $ sBoxType_isText (_sBox_boxType sbox)
          then Nothing -- SEltBox type changed to non-text
          else Just $ SomePotatoHandler $ updateBoxTextHandlerState True _potatoHandlerInput_selection tah
        _ -> Nothing
      where
        sowl = selectionToSuperOwl _potatoHandlerInput_selection
        rid = _superOwl_id sowl
        selt = superOwl_toSElt_hack sowl


  pRenderHandler tah' PotatoHandlerInput {..} = r where
    tah = updateBoxTextHandlerState False _potatoHandlerInput_selection tah'
    dls = _boxTextInputState_displayLines $ _boxTextHandler_state tah
    origBox = _boxTextInputState_box $ _boxTextHandler_state tah
    (x, y) = TZ._displayLines_cursorPos dls
    offsetMap = TZ._displayLines_offsetMap dls

    mlbox = do
      guard $ lBox_area origBox > 0

      -- TODO would be nice to assert that this exists...
      (alignxoff,_) <- Map.lookup y offsetMap
      let
        LBox p _ = _boxTextInputState_box $ _boxTextHandler_state tah
        offset = getOffset $ snd $ getSBox _potatoHandlerInput_selection
      return $ [LBox (p + (V2 (x + alignxoff) y) + offset) (V2 1 1)]

    r = HandlerRenderOutput $ fromMaybe [] mlbox
  pIsHandlerActive = _boxTextHandler_isActive
