package com.melody.runtime.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Maps iOS SF Symbols names to Material Icons.
 * Port of iOS system image handling.
 */
object SystemImageMapper {

    private val mapping: Map<String, ImageVector> = mapOf(
        // Navigation
        "chevron.right" to Icons.AutoMirrored.Filled.ArrowForward,
        "chevron.left" to Icons.AutoMirrored.Filled.ArrowBack,
        "arrow.left" to Icons.AutoMirrored.Filled.ArrowBack,
        "arrow.right" to Icons.AutoMirrored.Filled.ArrowForward,

        // Common
        "plus" to Icons.Default.Add,
        "minus" to Icons.Default.Remove,
        "xmark" to Icons.Default.Close,
        "checkmark" to Icons.Default.Check,
        "checkmark.circle" to Icons.Default.CheckCircle,
        "checkmark.circle.fill" to Icons.Default.CheckCircle,
        "magnifyingglass" to Icons.Default.Search,
        "gear" to Icons.Default.Settings,
        "gearshape" to Icons.Default.Settings,
        "gearshape.fill" to Icons.Default.Settings,
        "person" to Icons.Default.Person,
        "person.fill" to Icons.Default.Person,
        "person.2" to Icons.Default.People,
        "person.2.fill" to Icons.Default.People,
        "person.3" to Icons.Default.Groups,
        "person.3.fill" to Icons.Default.Groups,
        "person.crop.circle" to Icons.Default.AccountCircle,
        "person.circle" to Icons.Default.AccountCircle,
        "person.circle.fill" to Icons.Default.AccountCircle,
        "house" to Icons.Default.Home,
        "house.fill" to Icons.Default.Home,
        "star" to Icons.Default.Star,
        "star.fill" to Icons.Default.Star,
        "star.slash" to Icons.Default.StarBorder,
        "heart" to Icons.Default.Favorite,
        "heart.fill" to Icons.Default.Favorite,
        "trash" to Icons.Default.Delete,
        "trash.fill" to Icons.Default.Delete,
        "pencil" to Icons.Default.Edit,
        "square.and.pencil" to Icons.Default.Edit,

        // Alerts / Info
        "exclamationmark.triangle" to Icons.Default.Warning,
        "exclamationmark.triangle.fill" to Icons.Default.Warning,
        "exclamationmark.shield" to Icons.Default.Shield,
        "exclamationmark.shield.fill" to Icons.Default.Shield,
        "xmark.octagon" to Icons.Default.Error,
        "xmark.octagon.fill" to Icons.Default.Error,
        "info.circle" to Icons.Default.Info,
        "info.circle.fill" to Icons.Default.Info,
        "questionmark.circle" to Icons.Default.Help,

        // Actions
        "square.and.arrow.up" to Icons.Default.Share,
        "square.and.arrow.down" to Icons.Default.Download,
        "square.and.arrow.down.on.square" to Icons.Default.Download,
        "doc.on.doc" to Icons.Default.ContentCopy,
        "doc.on.clipboard" to Icons.Default.ContentPaste,
        "doc.on.clipboard.fill" to Icons.Default.ContentPaste,
        "arrow.clockwise" to Icons.Default.Refresh,
        "arrow.counterclockwise" to Icons.Default.Refresh,
        "arrow.triangle.2.circlepath" to Icons.Default.Sync,

        // Communication
        "envelope" to Icons.Default.Email,
        "envelope.fill" to Icons.Default.Email,
        "phone" to Icons.Default.Phone,
        "phone.fill" to Icons.Default.Phone,
        "message" to Icons.Default.Chat,
        "message.fill" to Icons.Default.Chat,
        "bell" to Icons.Default.Notifications,
        "bell.fill" to Icons.Default.Notifications,

        // Media
        "photo" to Icons.Default.Image,
        "photo.fill" to Icons.Default.Image,
        "photo.stack" to Icons.Default.Collections,
        "camera" to Icons.Default.CameraAlt,
        "camera.fill" to Icons.Default.CameraAlt,
        "play" to Icons.Default.PlayArrow,
        "play.fill" to Icons.Default.PlayArrow,
        "play.circle" to Icons.Default.PlayCircleFilled,
        "play.circle.fill" to Icons.Default.PlayCircleFilled,
        "play.tv" to Icons.Default.PlayCircleFilled,
        "play.tv.fill" to Icons.Default.PlayCircleFilled,
        "pause" to Icons.Default.Pause,
        "pause.fill" to Icons.Default.Pause,
        "pause.circle" to Icons.Default.PauseCircleFilled,
        "pause.circle.fill" to Icons.Default.PauseCircleFilled,
        "stop" to Icons.Default.Stop,
        "stop.fill" to Icons.Default.Stop,
        "stop.circle" to Icons.Default.StopCircle,
        "stop.circle.fill" to Icons.Default.StopCircle,

        // Charts
        "chart.bar" to Icons.Default.BarChart,
        "chart.bar.fill" to Icons.Default.BarChart,
        "chart.line.uptrend.xyaxis" to Icons.Default.ShowChart,
        "chart.pie" to Icons.Default.PieChart,
        "chart.pie.fill" to Icons.Default.PieChart,

        // Status
        "wifi" to Icons.Default.Wifi,
        "lock" to Icons.Default.Lock,
        "lock.fill" to Icons.Default.Lock,
        "lock.open" to Icons.Default.LockOpen,
        "lock.circle" to Icons.Default.Lock,
        "lock.rotation" to Icons.Default.Lock,
        "eye" to Icons.Default.Visibility,
        "eye.slash" to Icons.Default.VisibilityOff,
        "eye.fill" to Icons.Default.Visibility,
        "eye.slash.fill" to Icons.Default.VisibilityOff,

        // Containers / Shapes
        "circle" to Icons.Default.Circle,
        "circle.fill" to Icons.Default.Circle,
        "square" to Icons.Default.Square,
        "square.fill" to Icons.Default.Square,

        // Navigation/Menu
        "line.3.horizontal" to Icons.Default.Menu,
        "line.3.horizontal.decrease.circle" to Icons.Default.FilterList,
        "ellipsis" to Icons.Default.MoreVert,
        "ellipsis.circle" to Icons.Default.MoreVert,
        "ellipsis.circle.fill" to Icons.Default.MoreHoriz,

        // Files / Data
        "folder" to Icons.Default.Folder,
        "folder.fill" to Icons.Default.Folder,
        "doc" to Icons.Default.Description,
        "doc.fill" to Icons.Default.Description,
        "doc.text" to Icons.Default.Description,
        "doc.text.fill" to Icons.Default.Description,
        "doc.text.magnifyingglass" to Icons.Default.FindInPage,
        "list.bullet" to Icons.AutoMirrored.Filled.List,
        "list.bullet.rectangle" to Icons.Default.ViewList,
        "tag" to Icons.Default.Label,
        "tag.fill" to Icons.Default.Label,

        // Maps / Location
        "location" to Icons.Default.LocationOn,
        "location.fill" to Icons.Default.LocationOn,
        "map" to Icons.Default.Map,
        "map.fill" to Icons.Default.Map,

        // Shopping / Commerce
        "cart" to Icons.Default.ShoppingCart,
        "cart.fill" to Icons.Default.ShoppingCart,
        "creditcard" to Icons.Default.CreditCard,
        "creditcard.fill" to Icons.Default.CreditCard,

        // Misc
        "link" to Icons.Default.Link,
        "paperplane" to Icons.Default.Send,
        "paperplane.fill" to Icons.Default.Send,
        "calendar" to Icons.Default.CalendarToday,
        "clock" to Icons.Default.Schedule,
        "clock.fill" to Icons.Default.Schedule,
        "bolt" to Icons.Default.ElectricBolt,
        "bolt.fill" to Icons.Default.ElectricBolt,
        "power" to Icons.Default.PowerSettingsNew,

        // Server / Network
        "server.rack" to Icons.Default.Storage,
        "externaldrive" to Icons.Default.Storage,
        "externaldrive.fill" to Icons.Default.Storage,
        "externaldrive.fill.badge.icloud" to Icons.Default.Cloud,
        "network" to Icons.Default.Lan,
        "globe" to Icons.Default.Language,

        // App specific
        "rectangle.on.rectangle" to Icons.Default.Layers,
        "square.stack.3d.up" to Icons.Default.Layers,
        "square.stack.3d.up.fill" to Icons.Default.Layers,
        "shippingbox" to Icons.Default.Inventory,
        "shippingbox.fill" to Icons.Default.Inventory,
        "helm" to Icons.Default.DirectionsBoat,
        "key" to Icons.Default.Key,
        "key.fill" to Icons.Default.Key,
        "shield" to Icons.Default.Shield,
        "shield.fill" to Icons.Default.Shield,

        // Arrow
        "arrow.up" to Icons.Default.ArrowUpward,
        "arrow.down" to Icons.Default.ArrowDownward,
        "arrow.up.arrow.down" to Icons.Default.SwapVert,
        "rectangle.portrait.and.arrow.right" to Icons.AutoMirrored.Filled.ExitToApp,

        // Sliders
        "slider.horizontal.3" to Icons.Default.Tune,

        // More
        "plus.circle" to Icons.Default.AddCircle,
        "plus.circle.fill" to Icons.Default.AddCircle,
        "minus.circle" to Icons.Default.RemoveCircle,
        "minus.circle.fill" to Icons.Default.RemoveCircle,
        "xmark.circle" to Icons.Default.Cancel,
        "xmark.circle.fill" to Icons.Default.Cancel,
    )

    fun resolve(sfSymbolName: String): ImageVector {
        return mapping[sfSymbolName] ?: Icons.Default.HelpOutline
    }

    @Composable
    fun Icon(
        sfSymbolName: String,
        modifier: Modifier = Modifier,
        tint: Color = Color.Unspecified,
        contentDescription: String? = null
    ) {
        Icon(
            imageVector = resolve(sfSymbolName),
            contentDescription = contentDescription ?: sfSymbolName,
            modifier = modifier,
            tint = if (tint == Color.Unspecified) androidx.compose.material3.LocalContentColor.current else tint
        )
    }
}
