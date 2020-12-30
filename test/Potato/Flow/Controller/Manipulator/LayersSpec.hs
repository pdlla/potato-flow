{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RecursiveDo     #-}

module Potato.Flow.Controller.Manipulator.LayersSpec
  ( spec
  )
where

import           Relude                            hiding (empty, fromList)

import           Test.Hspec
import           Test.Hspec.Contrib.HUnit          (fromHUnitTest)
import           Test.HUnit

import           Potato.Flow
import           Potato.Flow.Controller.GoatWidget
import           Potato.Flow.Controller.Handler
import           Potato.Flow.Controller.Input

import           Potato.Flow.Common
import           Potato.Flow.TestStates

import           Data.Default
import qualified Data.IntMap                       as IM
import qualified Data.Sequence                     as Seq

moveOffset :: Int
moveOffset = 5

collapseOffset :: Int
collapseOffset = 0

hideOffset :: Int
hideOffset = 1

lockOffset :: Int
lockOffset = 2


numLayerEntriesEqualPredicate :: Int -> EverythingPredicate
numLayerEntriesEqualPredicate n = FunctionPredicate $
  (\(_, lentries) ->
    let nlentries = Seq.length lentries
    in ("LayerEntries count: " <> show nlentries <> " expected: " <> show n <> " lentries:\n" <> layerEntriesToPrettyText lentries, nlentries == n))
  . _goatState_layersState


numVisibleHiddenLayerEntriesEqualPredicate :: Int -> EverythingPredicate
numVisibleHiddenLayerEntriesEqualPredicate n = FunctionPredicate $
  (\(_, lentries) ->
    let nhidden = Seq.length $ Seq.filter (lockHiddenStateToBool . _layerEntry_hideState) lentries
    in ("Hidden: " <> show nhidden <> " expected: " <> show n <> " lentries: " <> layerEntriesToPrettyText lentries, nhidden == n))
  . _goatState_layersState

numVisibleLockedEltsLayerEntriesPredicate :: Int -> EverythingPredicate
numVisibleLockedEltsLayerEntriesPredicate n = FunctionPredicate $
  (\(_, lentries) ->
    let nlocked = Seq.length $ Seq.filter (lockHiddenStateToBool . _layerEntry_lockState) lentries
    in ("Locked: " <> show nlocked <> " expected: " <> show n <> " lentries:\n" <> layerEntriesToPrettyText lentries, nlocked == n))
  . _goatState_layersState

-- this should work with any initial state so long as default names aren't used
test_LayersHandler_basic :: Test
test_LayersHandler_basic = constructTest "basic" pfstate_basic1 bs expected where
  bs = [

      EWCLabel "select"
      , EWCMouse (LMouseData (V2 moveOffset 0) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 moveOffset 0) True MouseButton_Left [] True)

      , EWCLabel "deselect"
      , EWCMouse (LMouseData (V2 moveOffset 0) False MouseButton_Left [KeyModifier_Shift] True)
      , EWCMouse (LMouseData (V2 moveOffset 0) True MouseButton_Left [KeyModifier_Shift] True)

      , EWCLabel "select and cancel"
      , EWCMouse (LMouseData (V2 moveOffset 0) False MouseButton_Left [] True)
      , EWCKeyboard (KeyboardData KeyboardKey_Esc [])
      , EWCMouse (LMouseData (V2 moveOffset 0) True MouseButton_Left [] True)

      , EWCLabel "shift select 2 elts"
      , EWCMouse (LMouseData (V2 moveOffset 0) False MouseButton_Left [KeyModifier_Shift] True)
      , EWCMouse (LMouseData (V2 moveOffset 0) True MouseButton_Left [KeyModifier_Shift] True)
      , EWCMouse (LMouseData (V2 moveOffset 1) False MouseButton_Left [KeyModifier_Shift] True)
      , EWCMouse (LMouseData (V2 moveOffset 1) True MouseButton_Left [KeyModifier_Shift] True)

      , EWCLabel "out of bounds"
      , EWCMouse (LMouseData (V2 124 10232) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 124 10234) True MouseButton_Left [] True)

    ]
  expected = [
      LabelCheck "select"
      , numSelectedEltsEqualPredicate 0
      , numSelectedEltsEqualPredicate 1

      , LabelCheck "deselect"
      , numSelectedEltsEqualPredicate 1
      , numSelectedEltsEqualPredicate 0

      , LabelCheck "select and cancel"
      , numSelectedEltsEqualPredicate 0
      , numSelectedEltsEqualPredicate 0
      , numSelectedEltsEqualPredicate 0

      , LabelCheck "shift select 2 elts"
      , numSelectedEltsEqualPredicate 0
      , numSelectedEltsEqualPredicate 1
      , numSelectedEltsEqualPredicate 1
      , numSelectedEltsEqualPredicate 2

      , LabelCheck "out of bounds"
      , numSelectedEltsEqualPredicate 2
      , numSelectedEltsEqualPredicate 2 -- TODO change to 0 once deselect via LayersHandler is supported
    ]

test_LayersHandler_toggle :: Test
test_LayersHandler_toggle = constructTest "toggle" pfstate_basic1 bs expected where
  bs = [
      EWCLabel "lock"
      , EWCNothing
      , EWCMouse (LMouseData (V2 lockOffset 0) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 lockOffset 0) True MouseButton_Left [] True)

      , EWCLabel "hide"
      , EWCNothing
      , EWCMouse (LMouseData (V2 hideOffset 0) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 hideOffset 0) True MouseButton_Left [] True)

      -- TODO inherit/folder test stuff
    ]
  expected = [
      LabelCheck "lock"
      , numVisibleLockedEltsLayerEntriesPredicate 0
      , numVisibleLockedEltsLayerEntriesPredicate 1
      , numVisibleLockedEltsLayerEntriesPredicate 1

      , LabelCheck "hide"
      , numVisibleHiddenLayerEntriesEqualPredicate 0
      , numVisibleHiddenLayerEntriesEqualPredicate 1
      , numVisibleHiddenLayerEntriesEqualPredicate 1
    ]

test_LayersHandler_collapse :: Test
test_LayersHandler_collapse = constructTest "collapse" pfstate_basic2 bs expected where
  bs = [

      EWCLabel "expand fstart1"
      , EWCNothing
      , EWCMouse (LMouseData (V2 collapseOffset 0) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 collapseOffset 0) True MouseButton_Left [] True)
      , EWCLabel "expand fstart2"
      , EWCMouse (LMouseData (V2 (1+collapseOffset) 1) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 (1+collapseOffset) 1) True MouseButton_Left [] True)
      , EWCLabel "collapse fstart2"
      , EWCMouse (LMouseData (V2 (1+collapseOffset) 1) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 (1+collapseOffset) 1) True MouseButton_Left [] True)
      , EWCLabel "expand fstart3"
      , EWCMouse (LMouseData (V2 (1+collapseOffset) 2) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 (1+collapseOffset) 2) True MouseButton_Left [] True)
      , EWCLabel "collapse fstart1"
      , EWCMouse (LMouseData (V2 collapseOffset 0) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 collapseOffset 0) True MouseButton_Left [] True)

      -- TODO select folder test (not support yet)

    ]
  expected = [
      LabelCheck "expand fstart1"
      , numLayerEntriesEqualPredicate 1
      , numLayerEntriesEqualPredicate 3
      , numLayerEntriesEqualPredicate 3
      , LabelCheck "expand fstart2"
      , numLayerEntriesEqualPredicate 7
      , numLayerEntriesEqualPredicate 7
      , LabelCheck "collapse fstart2"
      , numLayerEntriesEqualPredicate 3
      , numLayerEntriesEqualPredicate 3
      , LabelCheck "expand fstart3"
      , numLayerEntriesEqualPredicate 5
      , numLayerEntriesEqualPredicate 5
      , LabelCheck "collapse fstart1"
      , numLayerEntriesEqualPredicate 1
      , numLayerEntriesEqualPredicate 1
    ]


test_LayersHandler_move :: Test
test_LayersHandler_move = constructTest "move" pfstate_basic1 bs expected where
  bs = [

      EWCLabel "select b1"
      , EWCMouse (LMouseData (V2 moveOffset 0) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 moveOffset 0) True MouseButton_Left [] True)

      , EWCLabel "drag b1"
      , EWCMouse (LMouseData (V2 moveOffset 0) False MouseButton_Left [] True)
      , EWCMouse (LMouseData (V2 moveOffset 4) True MouseButton_Left [] True)

      -- TODO folder drag/move

    ]
  expected = [
      LabelCheck "select b1"
      , numSelectedEltsEqualPredicate 0
      , numSelectedEltsEqualPredicate 1

      , LabelCheck "drag b1"
      , firstSelectedSuperSEltLabelPredicate (Just "b1") $ \(_,lp,_) -> lp == 0
      , firstSelectedSuperSEltLabelPredicate (Just "b1") $ \(_,lp,_) -> lp == 3
    ]


spec :: Spec
spec = do
  describe "LayersHandler" $ do
    fromHUnitTest $ test_LayersHandler_basic
    fromHUnitTest $ test_LayersHandler_toggle
    fromHUnitTest $ test_LayersHandler_collapse
    fromHUnitTest $ test_LayersHandler_move