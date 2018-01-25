package madgik.exareme.master.gateway.async.handler.entity;

import org.apache.http.entity.BasicHttpEntity;
import org.apache.http.nio.ContentEncoder;
import org.apache.http.nio.IOControl;
import org.apache.http.nio.entity.HttpAsyncContentProducer;
import org.apache.log4j.Logger;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.nio.channels.ReadableByteChannel;

import madgik.exareme.master.client.AdpDBClientQueryStatus;
import madgik.exareme.master.connector.DataSerialization;

/**
 * TODO flush output before suspend
 *
 * @author alex
 * @since 0.1
 */
public class NQueryResultEntity extends BasicHttpEntity implements HttpAsyncContentProducer {

    private static final Logger log = Logger.getLogger(NQueryResultEntity.class);

    private final AdpDBClientQueryStatus queryStatus;
    private final ByteBuffer buffer;
    private ReadableByteChannel channel;
    private NQueryStatusEntity.QueryStatusListener l;
    private DataSerialization format;

    public NQueryResultEntity(AdpDBClientQueryStatus status, DataSerialization ds,
                              int bufferSize) {
        super();
        queryStatus = status;
        buffer = ByteBuffer.allocate(bufferSize);
        channel = null;
        l = null;
        format = ds;
    }

    @Override public void produceContent(ContentEncoder encoder, IOControl ioctrl)
        throws IOException {

        if (queryStatus.hasFinished() == false && queryStatus.hasError() == false) {

            if(l == null) {

                l = new NQueryStatusEntity.QueryStatusListener(ioctrl);
                queryStatus.registerListener(l);
            }
            ioctrl.suspendOutput();
            return;
        }

        if (queryStatus.hasError() == false) {

            if (channel == null) {

                channel = Channels.newChannel(queryStatus.getResult(format));
            }
            channel.read(buffer);
            buffer.flip();
            int i = encoder.write(buffer);
            final boolean buffering = this.buffer.hasRemaining();
            this.buffer.compact();
            if (i < 1 && !buffering) {

                encoder.complete();
                close();
            }
        } else {
            if (queryStatus.getError().toString().contains("\n" +
                    "Operator VARIABLE:"))
            {
                String result = "{\"Error\":\"Please provide a variable that exists.\"}";
                encoder.write(ByteBuffer.wrap(result.getBytes()));
                encoder.complete();
                close();
            }
            else if(queryStatus.getError().toString().contains("\n" +
                    "Operator DATASET:"))
                {
                    String result = "{\"Error\":\"Please provide a dataset that exists.\"}";
                    encoder.write(ByteBuffer.wrap(result.getBytes()));
                    encoder.complete();
                    close();
                }
            else if(queryStatus.getError().toString().contains("\n" +
                    "Operator NULLTABLE:"))
            {
                String result = "{\"Error\":\"The input you provided gives an empty table. Please check your input.\"}";
                encoder.write(ByteBuffer.wrap(result.getBytes()));
                encoder.complete();
                close();
            }
            else {
                String result = "{\"Error\":\"Something went wrong.Please inform your system administrator " +
                        "to consult the logs.\"}";
                encoder.write(ByteBuffer.wrap(result.getBytes()));
                encoder.complete();
                close();
            }
        }
    }

    @Override public void close() throws IOException {
        queryStatus.close();
    }

    @Override public boolean isRepeatable() {
        return false;
    }
}
