<?php

namespace App\Jobs;

use App\Services\WhapifyService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Job async untuk kirim pesan WhatsApp via Whapify.
 *
 * Dipakai untuk operasi non-blocking di endpoint API (mis. send OTP).
 * Endpoint balas ke client dalam < 200ms; pengiriman WA jalan di
 * background lewat queue worker.
 *
 * Kalau Whapify error sementara, job otomatis retry sampai 3x dengan
 * delay backoff. Kalau gagal final, log warning (tapi tidak crash request).
 */
class SendWhapifyMessage implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $backoff = 5; // detik antar retry

    public function __construct(
        public string $recipient,
        public string $message,
    ) {
    }

    public function handle(WhapifyService $whapifyService): void
    {
        $result = $whapifyService->sendText($this->recipient, $this->message);

        if (!($result['ok'] ?? false)) {
            Log::warning('SendWhapifyMessage: send failed', [
                'recipient' => $this->recipient,
                'status_code' => $result['status_code'] ?? null,
                'message' => $result['message'] ?? null,
            ]);

            // Retry kalau bukan validation error (4xx) — error provider/network.
            $statusCode = $result['status_code'] ?? 500;
            if ($statusCode >= 500 || $statusCode === 408 || $statusCode === 429) {
                $this->release($this->backoff);
            }
        }
    }
}
