{-# LANGUAGE RecordWildCards #-}

module Potato.Flow.Controller.Manipulator.Pan (
  PanHandler(..)
) where

import           Relude

import           Potato.Flow.Controller.Handler
import           Potato.Flow.Controller.Input
import           Potato.Flow.Math

import           Data.Default


data PanHandler = PanHandler {
    _panHandler_pan :: XY
  }

instance Default PanHandler where
  def = PanHandler { _panHandler_pan = 0 }

instance PotatoHandler PanHandler where
  pHandlerName _ = handlerName_pan
  pHandleMouse ph@PanHandler {..} PotatoHandlerInput {..} (RelMouseDrag MouseDrag {..}) = Just $ case _mouseDrag_state of
    MouseDragState_Cancelled -> def { _potatoHandlerOutput_pan = Just $ - _panHandler_pan }
    MouseDragState_Down -> def { _potatoHandlerOutput_nextHandler = Just $ SomePotatoHandler ph }
    _ -> def {
        _potatoHandlerOutput_nextHandler = case _mouseDrag_state of
          MouseDragState_Dragging -> Just $ SomePotatoHandler ph { _panHandler_pan = delta }
          MouseDragState_Up -> Nothing
          _ -> error "not posible"
        , _potatoHandlerOutput_pan = Just (delta - _panHandler_pan)
      } where delta = _mouseDrag_to - _mouseDrag_from

  pHandleKeyboard PanHandler {..} PotatoHandlerInput {..} kbd = Nothing
  pRenderHandler _ PotatoHandlerInput {..} = def
  pIsHandlerActive _ = True
