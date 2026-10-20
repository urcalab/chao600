package cl.urcalab.chao600

import android.telecom.Call
import android.telecom.CallScreeningService

/** Android asks this service about every incoming call, before it rings. */
class CallBlockerService : CallScreeningService() {
    override fun onScreenCall(callDetails: Call.Details) {
        val store = BlockStore.get(this)
        val number = callDetails.handle?.schemeSpecificPart
        val prefix = if (callDetails.callDirection == Call.Details.DIRECTION_INCOMING) {
            BlockRules.match(number, store.config.value)
        } else {
            null
        }

        if (prefix == null || number == null) {
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // Answer first: the call must not wait on the log write.
        respondToCall(
            callDetails,
            CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipNotification(true)
                .build(),
        )
        store.record(BlockedCall(number, prefix, System.currentTimeMillis()))
    }
}
