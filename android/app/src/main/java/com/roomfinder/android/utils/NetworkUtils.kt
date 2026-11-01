package com.roomfinder.android.utils

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class NetworkUtils(private val context: Context) {
    
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val _networkState = MutableLiveData<NetworkState>()
    val networkState: LiveData<NetworkState> = _networkState
    
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    
    init {
        checkInitialNetworkState()
    }
    
    fun isNetworkAvailable(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
               capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
    
    fun isWifiConnected(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }
    
    fun isCellularConnected(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
    }
    
    fun getNetworkType(): NetworkType {
        val network = connectivityManager.activeNetwork ?: return NetworkType.NONE
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return NetworkType.NONE
        
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> NetworkType.WIFI
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> NetworkType.CELLULAR
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> NetworkType.ETHERNET
            else -> NetworkType.OTHER
        }
    }
    
    fun startNetworkMonitoring() {
        if (networkCallback != null) return
        
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                updateNetworkState(NetworkState.CONNECTED)
            }
            
            override fun onLost(network: Network) {
                updateNetworkState(NetworkState.DISCONNECTED)
            }
            
            override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                val isValidated = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                val hasInternet = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                
                if (isValidated && hasInternet) {
                    updateNetworkState(NetworkState.CONNECTED)
                } else {
                    updateNetworkState(NetworkState.LIMITED)
                }
            }
        }
        
        val networkRequest = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        connectivityManager.registerNetworkCallback(networkRequest, networkCallback!!)
    }
    
    fun stopNetworkMonitoring() {
        networkCallback?.let {
            connectivityManager.unregisterNetworkCallback(it)
            networkCallback = null
        }
    }
    
    suspend fun checkInternetConnectivity(): Boolean = withContext(Dispatchers.IO) {
        try {
            val url = URL("https://www.google.com")
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.requestMethod = "HEAD"
            
            val responseCode = connection.responseCode
            connection.disconnect()
            
            responseCode == HttpURLConnection.HTTP_OK
        } catch (e: IOException) {
            false
        }
    }
    
    suspend fun checkServerReachability(serverUrl: String): ServerReachabilityResult = withContext(Dispatchers.IO) {
        try {
            val url = URL(serverUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.requestMethod = "HEAD"
            
            val startTime = System.currentTimeMillis()
            val responseCode = connection.responseCode
            val responseTime = System.currentTimeMillis() - startTime
            
            connection.disconnect()
            
            when (responseCode) {
                in 200..299 -> ServerReachabilityResult.Success(responseTime)
                in 400..499 -> ServerReachabilityResult.ClientError(responseCode)
                in 500..599 -> ServerReachabilityResult.ServerError(responseCode)
                else -> ServerReachabilityResult.UnknownError(responseCode)
            }
        } catch (e: IOException) {
            ServerReachabilityResult.NetworkError(e.message ?: "Network error")
        }
    }
    
    fun getNetworkInfo(): NetworkInfo {
        val network = connectivityManager.activeNetwork
        val capabilities = network?.let { connectivityManager.getNetworkCapabilities(it) }
        
        return NetworkInfo(
            isConnected = isNetworkAvailable(),
            networkType = getNetworkType(),
            isMetered = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false,
            linkDownstreamBandwidthKbps = capabilities?.linkDownstreamBandwidthKbps ?: 0,
            linkUpstreamBandwidthKbps = capabilities?.linkUpstreamBandwidthKbps ?: 0
        )
    }
    
    fun shouldRetryRequest(attemptCount: Int, maxRetries: Int = 3): Boolean {
        if (!isNetworkAvailable()) return false
        return attemptCount < maxRetries
    }
    
    fun calculateRetryDelay(attemptCount: Int): Long {
        // Exponential backoff: 1s, 2s, 4s, 8s, etc.
        return (1000 * Math.pow(2.0, attemptCount.toDouble())).toLong().coerceAtMost(30000)
    }
    
    private fun checkInitialNetworkState() {
        val state = if (isNetworkAvailable()) {
            NetworkState.CONNECTED
        } else {
            NetworkState.DISCONNECTED
        }
        updateNetworkState(state)
    }
    
    private fun updateNetworkState(state: NetworkState) {
        CoroutineScope(Dispatchers.Main).launch {
            _networkState.value = state
        }
    }
    
    enum class NetworkState {
        CONNECTED,
        DISCONNECTED,
        LIMITED
    }
    
    enum class NetworkType {
        WIFI,
        CELLULAR,
        ETHERNET,
        OTHER,
        NONE
    }
    
    data class NetworkInfo(
        val isConnected: Boolean,
        val networkType: NetworkType,
        val isMetered: Boolean,
        val linkDownstreamBandwidthKbps: Int,
        val linkUpstreamBandwidthKbps: Int
    )
    
    sealed class ServerReachabilityResult {
        data class Success(val responseTimeMs: Long) : ServerReachabilityResult()
        data class ClientError(val statusCode: Int) : ServerReachabilityResult()
        data class ServerError(val statusCode: Int) : ServerReachabilityResult()
        data class NetworkError(val message: String) : ServerReachabilityResult()
        data class UnknownError(val statusCode: Int) : ServerReachabilityResult()
    }
}