module ButtonScript (main) where

import Browser.Runtime (getUrl)
import Data.Array.Partial (head)
import Data.Maybe (Maybe (Just, Nothing))
import Data.Options ((:=))
import Effect (Effect)
import Effect.Class (liftEffect)
import Effect.Exception (Error, message)
import Effect.Promise (class Deferred, Promise, runPromise)
import Partial.Unsafe (unsafePartial)
import Vanilla.Dom.Element (classList)
import Vanilla.Dom.Event (Event, eventTarget, addEventListener, fromEventTarget)
import Vanilla.Dom.Document (document)
import Vanilla.Dom.Node (querySelector, textContent, fromNode')
import Vanilla.Dom.TokenList (tokenListHas, tokenListAdd, tokenListRemove)

import Effect.Console as Console
import Browser.Tabs as Tabs

import Prelude

reportScriptError :: Error -> Effect Unit
reportScriptError err = do
    Console.error (message err)
    tokenListAdd "hidden" <<< classList <<< fromNode'
        <<< querySelector "#popup-content" $ document
    tokenListRemove "hidden" <<< classList <<< fromNode'
        <<< querySelector "#error-content" $ document


main :: Effect Unit
main = do
    runPromise pure reportScriptError $ void $
        Tabs.executeScriptCurrent $
            Tabs.file := "/build/content_script.js"
    addEventListener "click" buttonClicked document


-- | Action that runs when something on the thingy was clicked. May noy be a
-- | button, but only handles button clicks
buttonClicked :: Event -> Effect Unit
buttonClicked ev =
    Console.log "Button pressed" *>
    (runPromise pure report $ buttonClicked' ev)
    where report e = Console.error $ "Failed to beastify: " <> message e

buttonClicked' :: Deferred => Event -> Promise Unit
buttonClicked' event = case fromEventTarget $ eventTarget event of
    Nothing -> liftEffect $ Console.error "Bad event target"
    Just target ->
        let targetClasses = classList target
        in case unit of
            _ | tokenListHas "beast" targetClasses -> do
                  tabs <- Tabs.query $
                           Tabs.active := true
                        <> Tabs.currentWindow := true
                  let content = textContent target
                  beastify content
              | tokenListHas "reset" targetClasses -> do
                  let content = textContent target
                  reset
            otherwise -> pure unit



beastNameToUrl :: String -> String
beastNameToUrl name =
    let imageName = case name of
         "Frog"  -> "frog.jpg"
         "Snake" -> "snake.jpg"
         "Turtle" -> "turtle.jpg"
         _ -> "404.jpg"
    in getUrl $ "resources/beasts/" <> imageName


-- | Inset page-hiding CSS into active tab, and send a beastify message to the
-- | script of argument tab (which should also be active)
beastify
    :: Deferred
    => String -- ^ Text content of button pressed
    -> Promise Unit
beastify buttonContent = do
    tabs <- Tabs.query $
             Tabs.active := true
          <> Tabs.currentWindow := true
    Tabs.insertCssCurrent $
        Tabs.code := hidePageCss
    let targetTab = unsafePartial $ head $ tabs
    let target = targetTab.id
    let url = beastNameToUrl buttonContent
    liftEffect <<< Console.log $ "Sending besatify message: " <> url
    _ <- Tabs.sendMessage target {command: "beastify", beastURL: url}
    pure unit

-- | Undo effects of beastify
reset :: Deferred => Promise Unit
reset = do
    tabs <- Tabs.query $
             Tabs.active := true
          <> Tabs.currentWindow := true
    Tabs.insertCssCurrent $
        Tabs.code := hidePageCss
    let targetTab = unsafePartial $ head $ tabs
    let target = targetTab.id
    void $ Tabs.sendMessage target {command: "reset"}


hidePageCss :: String
hidePageCss = """body > :not(.beastify-image) {
    display: none;
};
 """
