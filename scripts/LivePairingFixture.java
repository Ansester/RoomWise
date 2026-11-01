import fitcheck.DemoKt;
import fitcheck.LivePreviewSession;
import fitcheck.Product;
import kotlin.Unit;

import java.net.InetAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/** Real desktop host and shared fixtures, for check-live-pairing.sh only. No provider calls. */
public final class LivePairingFixture {
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Expected an endpoint output file.");
            System.exit(2);
        }
        ScheduledExecutorService timer = Executors.newSingleThreadScheduledExecutor(work -> {
            Thread thread = new Thread(work, "RoomWise-pairing-fixture");
            thread.setDaemon(true);
            return thread;
        });
        AtomicReference<LivePreviewSession> current = new AtomicReference<>();
        AtomicBoolean advanced = new AtomicBoolean();
        List<Product> products = DemoKt.demoProducts();
        try (LivePreviewSession host = new LivePreviewSession(id -> {
            // C is published only after a genuine native-client POST selects B.
            if ("fixture-b".equals(id) && advanced.compareAndSet(false, true)) {
                timer.schedule(() -> current.get().publish(products, "fixture-c"), 1800, TimeUnit.MILLISECONDS);
            }
            return Unit.INSTANCE;
        })) {
            current.set(host);
            host.publish(products, "fixture-a");
            String endpoint = host.start(InetAddress.getByName("127.0.0.1")).get(0);
            Files.writeString(Path.of(args[0]), endpoint, StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE);
            // Bound the listener even if the controlling test process exits unexpectedly.
            new CountDownLatch(1).await(180, TimeUnit.SECONDS);
        } catch (Exception ignored) {
            // The temporary bearer URL must never appear in stdout or diagnostic traces.
            System.err.println("Local JVM pairing fixture failed.");
            System.exit(1);
        } finally {
            timer.shutdownNow();
        }
    }
}
