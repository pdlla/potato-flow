{-# LANGUAGE RecordWildCards #-}

module Potato.Flow.RenderSpec(
  spec
) where

import           Relude                 hiding (empty, fromList)

import           Test.Hspec

import           Data.Default           (def)
import qualified Data.IntMap            as IM
import qualified Data.Text              as T

import           Potato.Flow
import           Potato.Flow.TestStates

testCanvas :: Int -> Int -> Int -> Int -> RenderedCanvasRegion
testCanvas x y w h = emptyRenderedCanvasRegion (LBox (V2 x y) (V2 w h))

spec :: Spec
spec = do
  describe "Canvas" $ do
    it "potato renders blank text" $ do
      let
        (w,h) = (1003, 422)
        canvasText = renderedCanvasToText (testCanvas (-540) 33 w h)
      T.length canvasText `shouldBe` w * h + h - 1
    it "potato renders stuff" $ do
      let
        canvas1 = testCanvas (-12) (-44) 100 100
        n = 10
        selts = flip map [1..n] $ \i ->
          SEltBox $ def {
              _sBox_box    = LBox (V2 (i*2) 0) (V2 2 2)
            }
        canvas2 = potatoRender selts canvas1
        canvas2Text = renderedCanvasToText canvas2
      --putTextLn $ canvas2Text
      T.length (T.filter (\x -> x /= ' ' && x /= '\n') canvas2Text) `shouldBe` n*4
    it "renders negative LBox" $ do
      let
        canvas1 = testCanvas 0 0 20 20
        selt = SEltBox $ def {
            _sBox_box    = LBox (V2 10 10) (V2 (-10) (-10))
          }
        canvas2 = potatoRender [selt] canvas1
        canvas2Text = renderedCanvasToText canvas2
      T.length (T.filter (\x -> x /= ' ' && x /= '\n') canvas2Text) `shouldBe` 100
    it "renders to a region" $ do
      let
        fillBox = LBox (V2 (-12) (-44)) (V2 100 100)
        renderBox = LBox (V2 (-1) 10) (V2 10 10)
        canvas1 = emptyRenderedCanvasRegion fillBox
        selt = SEltBox $ def {
            _sBox_box    = fillBox
          }
        canvas2 = render renderBox [selt] canvas1
        canvas2Text = renderedCanvasToText canvas2
        canvas2TextRegion = renderedCanvasRegionToText renderBox canvas2
      --putTextLn $ canvas2Text
      T.length (T.filter (\x -> x /= ' ' && x /= '\n') canvas2Text) `shouldBe` lBox_area renderBox
      T.length (T.filter (\x -> x /= ' ' && x /= '\n') canvas2TextRegion) `shouldBe` lBox_area renderBox
    it "moveRenderedCanvasRegionNoReRender - translate" $ do
      let
        -- fill the whole canvas
        canvas1 = testCanvas 0 0 100 100
        selt = SEltBox $ def {
            _sBox_box    = LBox (V2 0 0) (V2 100 100)
          }
        canvas2 = potatoRender [selt] canvas1
        target = LBox (V2 (-50) (-50)) (V2 100 100)
        canvas3 = moveRenderedCanvasRegionNoReRender target canvas2
        canvas3Text = renderedCanvasToText canvas3
      T.length (T.filter (\x -> x /= ' ' && x /= '\n') canvas3Text) `shouldBe` 50*50
    it "moveRenderedCanvasRegionNoReRender - resize" $ do
      let
        canvas1 = testCanvas 0 0 50 100
        -- fill the whole canvas and then some
        selt = SEltBox $ def {
            _sBox_box    = LBox (V2 0 0) (V2 100 100)
          }
        canvas2 = potatoRender [selt] canvas1
        target = LBox (V2 0 0) (V2 100 50)
        canvas3 = moveRenderedCanvasRegionNoReRender target canvas2
        canvas3Text = renderedCanvasToText canvas3
      T.length (T.filter (\x -> x /= ' ' && x /= '\n') canvas3Text) `shouldBe` 50*50
    it "moveRenderedCanvasRegion" $ do
      let
        initial = LBox (V2 0 0) (V2 50 100)
        target = LBox (V2 0 0) (V2 100 50)
        selt = SEltBox $ def {
            _sBox_box    = LBox (V2 0 0) (V2 100 100)
          }
        state0 = owlPFState_fromSElts [selt] initial
        bps0 = BroadPhaseState $ bPTreeFromOwlPFState state0
        canvas0 = potatoRenderPFState state0 $ emptyRenderedCanvasRegion initial
        -- only thing changed is the canvas size
        canvas1 = moveRenderedCanvasRegion bps0 (_owlPFState_owlTree state0) target canvas0
      --liftIO $ printRenderedCanvasRegion canvas0
      --liftIO $ printRenderedCanvasRegion canvas1
      -- TODO test something
      canvas1 `shouldBe` canvas1
    it "updateCanvas - basic" $ do
      let
        --makeChange rid lb = IM.singleton rid $ Just (SEltLabel (show rid) (SEltBox $ SBox lb def def def SBoxType_Box))
        canvas0 = testCanvas 0 0 100 100
        state0 = owlpfstate_basic1
        bpt0 = bPTreeFromOwlPFState state0
        -- TODO actual changes
        changes1 = IM.empty
        (aabbs1, bps1) = update_bPTree IM.empty bpt0
        state1 = state0
        canvas1 = updateCanvas changes1 aabbs1 bps1 state1 canvas0
      -- TODO test something
      canvas1 `shouldBe` canvas1
