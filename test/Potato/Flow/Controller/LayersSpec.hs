{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RecursiveDo     #-}

module Potato.Flow.Controller.LayersSpec
  ( spec
  )
where

import           Relude                        hiding (empty, fromList)

import           Test.Hspec
import           Test.Hspec.Contrib.HUnit      (fromHUnitTest)
import           Test.HUnit

import           Potato.Flow
import           Potato.Flow.Controller.Input
import           Potato.Flow.Controller.Layers

import           Potato.Flow.Deprecated.TestStates

import           Data.Default
import qualified Data.IntMap                   as IM
import qualified Data.Sequence                 as Seq
import           Data.Tuple.Extra


someState1 :: PFState
someState1 = PFState {
      _pFState_layers = Seq.fromList [0..5]
      , _pFState_directory = IM.fromList [
          (0, folderStart)
            , (1, someSEltLabel)
            , (2, someSEltLabel)
            , (3, someSEltLabel)
            , (4, someSEltLabel)
            , (5, folderEnd)
        ]
      , _pFState_canvas = someSCanvas
  }
someState2 :: PFState
someState2 = PFState {
      _pFState_layers = Seq.fromList [0..11]
      , _pFState_directory = IM.fromList [
          (0, folderStart)
            , (1, folderStart)
              , (2, someSEltLabel)
              , (3, folderStart)
                , (4, someSEltLabel)
                , (5, folderEnd)
              , (6, someSEltLabel)
              , (7, folderEnd)
            , (8, someSEltLabel)
            , (9, folderStart)
              , (10, folderEnd)
            , (11, folderEnd)
        ]
      , _pFState_canvas = someSCanvas
  }

-- multiple (4) folders at top level
someState3 :: PFState
someState3 = PFState {
      _pFState_layers = Seq.fromList [0..15]
      , _pFState_directory = IM.fromList [
          (0, folderStart)
            , (1, folderStart)
              , (2, someSEltLabel)
              , (3, folderEnd)
            , (4, someSEltLabel)
            , (5, folderStart)
              , (6, folderEnd)
            , (7, someSEltLabel)
            , (8, folderEnd)
          , (9, folderStart)
            , (10, folderEnd)
          , (11, folderStart)
            , (12, folderEnd)
          , (13, folderStart)
            , (14, someSEltLabel)
            , (15, folderEnd)
        ]
      , _pFState_canvas = someSCanvas
  }


createExpandAllLayerMetaMap :: PFState -> LayerMetaMap
createExpandAllLayerMetaMap PFState {..} = fmap (\_ -> def { _layerMeta_isCollapsed = False }) _pFState_directory


spec :: Spec
spec = do
  describe "Layers" $ do
    describe "generateLayersNew" $ do
      it "basic" $ do
        -- empty LayerMetaMap means everything is collapsed by default
        Seq.length (generateLayersNew someState1 IM.empty) `shouldBe` 1
        Seq.length (generateLayersNew someState2 IM.empty) `shouldBe` 1
      it "handles empty state" $ do
        Seq.length (generateLayersNew emptyPFState IM.empty) `shouldBe` 0
    describe "toggleLayerEntry" $ do
      it "basic1" $ do
        -- open 0
        let
          lmm_0 = IM.empty -- everything collapsed
          lentries_0 = generateLayersNew someState1 lmm_0
          (lmm_1, lentries_1) = toggleLayerEntry someState1 (lmm_0, lentries_0) 0 LHCO_ToggleCollapse
        Seq.length lentries_1 `shouldBe` 5

        -- hide 0
        let
          (lmm_2, lentries_2) = toggleLayerEntry someState1 (lmm_1, lentries_1) 0 LHCO_ToggleHide
        _layerEntry_hideState (Seq.index lentries_2 0) `shouldBe` LHS_True
        forM_ [1,2,3,4] $ \i -> do
          _layerEntry_hideState (Seq.index lentries_2 i) `shouldBe` LHS_False_InheritTrue

        -- hide 1, show 0
        let
          (lmm_3, lentries_3) = toggleLayerEntry someState1 (lmm_2, lentries_2) 1 LHCO_ToggleHide
          (lmm_4, lentries_4) = toggleLayerEntry someState1 (lmm_3, lentries_3) 0 LHCO_ToggleHide
        forM_ [0,2,3,4] $ \i -> do
          _layerEntry_hideState (Seq.index lentries_4 i) `shouldBe` LHS_False
        _layerEntry_hideState (Seq.index lentries_4 1) `shouldBe` LHS_True

        -- lock 4
        let
          (lmm_5, lentries_5) = toggleLayerEntry someState1 (lmm_4, lentries_4) 4 LHCO_ToggleLock
        _layerEntry_lockState (Seq.index lentries_5 4) `shouldBe` LHS_True

        -- close first folder
        let
          (lmm_final, lentries_final) = toggleLayerEntry someState1 (lmm_5, lentries_5) 0 LHCO_ToggleCollapse
        Seq.length lentries_final `shouldBe` 1
        lentries_final `shouldBe` lentries_0
      it "basic2" $ do
        let
          lmm_0 = createExpandAllLayerMetaMap someState2 -- everything expanded
          lentries_0 = generateLayersNew someState2 lmm_0
        Seq.length lentries_0 `shouldBe` 8

        -- ensure layer entry 7 is rid 9
        (fst3 . _layerEntry_superSEltLabel) (Seq.index lentries_0 7) `shouldBe` 9

        -- collapse layer entry 7, which should do nothing because it's an empty folder
        let
          (lmm_1, lentries_1) = toggleLayerEntry someState1 (lmm_0, lentries_0) 7 LHCO_ToggleCollapse
        Seq.length lentries_1 `shouldBe` 8

      it "basic3" $ do
        let
          lmm_0 = IM.empty -- everything collapsed
          lentries_0 = generateLayersNew someState3 lmm_0
        Seq.length lentries_0 `shouldBe` 4

        -- ensure layer entry 3 is rid 13
        (fst3 . _layerEntry_superSEltLabel) (Seq.index lentries_0 3) `shouldBe` 13

        -- expand last folder, there should be one more element
        let
          (lmm_1, lentries_1) = toggleLayerEntry someState3 (lmm_0, lentries_0) 3 LHCO_ToggleCollapse
        Seq.length lentries_1 `shouldBe` 5
    describe "updateLayers" $ do
      it "basic" $ do
        let
          state_0 = someState1
          lmm_0 = createExpandAllLayerMetaMap state_0 -- everything expanded
          lentries_0 = generateLayersNew state_0 lmm_0

          (state_1, changes) = do_deleteElts [(4,4,someSEltLabel)] state_0
          (lmm_1, lentries_1) = updateLayers state_1 changes (lmm_0, lentries_0)
        Seq.length lentries_1 `shouldBe` 4
