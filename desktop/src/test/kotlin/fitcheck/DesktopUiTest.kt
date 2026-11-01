package fitcheck

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.toAwtImage
import org.junit.Rule
import org.junit.Test
import java.io.File
import javax.imageio.ImageIO

class DesktopUiTest {
    @get:Rule val ui = createComposeRule()

    @Test
    fun testRoomWiseStandardResolution() {
        ui.setContent {
            Box(Modifier.size(1320.dp, 880.dp)) {
                RoomWiseApp()
            }
        }
        ui.onAllNodesWithText("Explore sample room").onFirst().performClick()
        ui.waitForIdle()

        ui.onAllNodesWithText("Sample room").onFirst().assertExists()
        ui.onAllNodesWithText("62 × 64 × 112 cm").onFirst().assertExists()
        ui.onNodeWithText("Fits captured geometry").assertExists()

        ui.onNodeWithText("+90°").performClick()
        ui.waitForIdle()
        ui.onNodeWithText("Rotation 90°").assertExists()

        ui.onNodeWithText("Reset").performClick()
        ui.waitForIdle()
        ui.onNodeWithText("Rotation 0°").assertExists()

        val rawImage = ui.onRoot().captureToImage().toAwtImage()
        val image1320 = java.awt.image.BufferedImage(1320, 880, java.awt.image.BufferedImage.TYPE_INT_ARGB)
        val g1 = image1320.createGraphics()
        g1.setRenderingHint(java.awt.RenderingHints.KEY_INTERPOLATION, java.awt.RenderingHints.VALUE_INTERPOLATION_BILINEAR)
        g1.drawImage(rawImage, 0, 0, 1320, 880, null)
        g1.dispose()

        File("build").mkdirs()
        ImageIO.write(image1320, "png", File("build/ui-1320x880.png"))
    }

    @Test
    fun testRoomWiseCompactResolution() {
        ui.setContent {
            Box(Modifier.size(1024.dp, 768.dp)) {
                RoomWiseApp()
            }
        }
        ui.onAllNodesWithText("Explore sample room").onFirst().performClick()
        ui.waitForIdle()

        ui.onAllNodesWithText("Sample room").onFirst().assertExists()
        ui.onAllNodesWithText("62 × 64 × 112 cm").onFirst().assertExists()

        val rawImage = ui.onRoot().captureToImage().toAwtImage()
        val image1024 = java.awt.image.BufferedImage(1024, 768, java.awt.image.BufferedImage.TYPE_INT_ARGB)
        val g2 = image1024.createGraphics()
        g2.drawImage(rawImage, 0, 0, 1024, 768, null)
        g2.dispose()

        File("build").mkdirs()
        ImageIO.write(image1024, "png", File("build/ui-1024x768.png"))
    }
}
