require "rails_helper"

RSpec.describe GifCropperService do
  # Минимальный мок записи с поддержкой вложений
  let(:blob_double) { instance_double(ActiveStorage::Blob, filename: ActiveStorage::Filename.new("cropped_animation.gif")) }
  let(:attached_file_double) do
    double(ActiveStorage::Attached::One, attached?: true, blob: blob_double)
  end
  let(:record) do
    instance_double(Photo, save: true, errors: instance_double(ActiveModel::Errors, full_messages: []))
  end
  let(:attachment) do
    double(
      ActiveStorage::Attached::One,
      attached?: true,
      record: record,
      content_type: "image/gif",
      filename: ActiveStorage::Filename.new("animation.gif"),
      purge: true,
      download: true,
      attach: true
    )
  end

  # Заглушка транзакции для обработки Rollback
  before do
    allow(record).to receive(:file).and_return(attached_file_double)
    allow(attached_file_double).to receive(:attach)
    allow(ActiveRecord::Base).to receive(:transaction) do |&_block|
      begin
        _block.call
      rescue ActiveRecord::Rollback
        # Тихая обработка rollback как в реальной AR-транзакции
      end
    end
  end

  describe "#process_and_replace" do
    context "when attachment is not attached" do
      before { allow(attachment).to receive(:attached?).and_return(false) }

      it "returns early without processing" do
        service = described_class.new(attachment)
        expect(service).not_to receive(:system)
        service.process_and_replace
      end
    end

    context "when content type is not GIF" do
      before { allow(attachment).to receive(:content_type).and_return("image/png") }

      it "returns early without processing" do
        service = described_class.new(attachment)
        expect(service).not_to receive(:system)
        service.process_and_replace
      end
    end

    context "when attachment is a valid GIF" do
      let(:input_tempfile) { instance_double(Tempfile, path: "/tmp/input.gif", close!: true) }
      let(:output_tempfile) { instance_double(Tempfile, path: "/tmp/output.gif", close!: true) }
      let(:mini_magick_before) { instance_double(MiniMagick::Image, width: 800, height: 600, destroy!: true) }
      let(:mini_magick_after) { instance_double(MiniMagick::Image, width: 512, height: 512, destroy!: true) }

      before do
        # Заглушка Tempfile — первый вызов input, второй output
        tempfile_calls = 0
        allow(Tempfile).to receive(:new) do
          tempfile_calls += 1
          tempfile_calls.odd? ? input_tempfile : output_tempfile
        end

        # Заглушка скачивания файла
        allow(attachment).to receive(:download).and_yield("fake gif binary data")

        # Заглушка File.open для записи
        allow(File).to receive(:open).with("/tmp/input.gif", "wb").and_yield(StringIO.new)
        # Заглушка File.open для чтения
        allow(File).to receive(:open).with("/tmp/output.gif", "rb").and_return(StringIO.new("cropped gif data"))

        # Заглушка проверок существования и размера
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(1024)

        # Заглушка MiniMagick::Image.open для проверки размеров
        magick_calls = 0
        allow(MiniMagick::Image).to receive(:open) do
          magick_calls += 1
          # Вызовы 1-2: get_dimensions, 3+: validate_output
          magick_calls <= 2 ? mini_magick_before : mini_magick_after
        end
      end

      it "downloads, processes, and replaces the GIF attachment" do
        service = described_class.new(attachment)
        allow(service).to receive(:system).and_return(true)

        service.process_and_replace

        expect(attachment).to have_received(:download)
        expect(attachment).to have_received(:purge)
        expect(attached_file_double).to have_received(:attach).with(
          hash_including(filename: "cropped_animation.gif", content_type: "image/gif")
        )
        expect(record).to have_received(:save)
      end

      it "executes ImageMagick convert with correct arguments" do
        service = described_class.new(attachment)
        allow(service).to receive(:system).and_return(true)

        service.process_and_replace

        expect(service).to have_received(:system).with(
          "convert",
          "/tmp/input.gif",
          "-coalesce",
          "-resize", "512x512^",
          "-gravity", "center",
          "-extent", "512x512",
          "-background", "none",
          "-layers", "optimize",
          "/tmp/output.gif"
        )
      end

      it "cleans up tempfiles after successful processing" do
        service = described_class.new(attachment)
        allow(service).to receive(:system).and_return(true)

        service.process_and_replace

        expect(input_tempfile).to have_received(:close!)
        expect(output_tempfile).to have_received(:close!)
      end
    end

    context "when system command fails" do
      let(:input_tempfile) { instance_double(Tempfile, path: "/tmp/input.gif", close!: true) }
      let(:output_tempfile) { instance_double(Tempfile, path: "/tmp/output.gif", close!: true) }
      let(:mini_magick_image) { instance_double(MiniMagick::Image, width: 800, height: 600, destroy!: true) }

      before do
        tempfile_calls = 0
        allow(Tempfile).to receive(:new) do
          tempfile_calls += 1
          tempfile_calls.odd? ? input_tempfile : output_tempfile
        end

        allow(attachment).to receive(:download).and_yield("fake gif data")
        allow(File).to receive(:open).with("/tmp/input.gif", "wb").and_yield(StringIO.new)
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:size).and_return(0)
        allow(MiniMagick::Image).to receive(:open).and_return(mini_magick_image)
      end

      it "raises an error" do
        service = described_class.new(attachment)
        allow(service).to receive(:system).and_return(false)

        expect { service.process_and_replace }.to raise_error(RuntimeError, /Failed to process GIF/)
      end

      it "cleans up tempfiles even on failure" do
        service = described_class.new(attachment)
        allow(service).to receive(:system).and_return(false)

        expect { service.process_and_replace }.to raise_error(RuntimeError)

        expect(input_tempfile).to have_received(:close!)
        expect(output_tempfile).to have_received(:close!)
      end
    end

    context "when output dimensions are invalid" do
      let(:input_tempfile) { instance_double(Tempfile, path: "/tmp/input.gif", close!: true) }
      let(:output_tempfile) { instance_double(Tempfile, path: "/tmp/output.gif", close!: true) }
      let(:mini_magick_before) { instance_double(MiniMagick::Image, width: 800, height: 600, destroy!: true) }
      let(:mini_magick_invalid) { instance_double(MiniMagick::Image, width: 256, height: 256, destroy!: true) }

      before do
        tempfile_calls = 0
        allow(Tempfile).to receive(:new) do
          tempfile_calls += 1
          tempfile_calls.odd? ? input_tempfile : output_tempfile
        end

        allow(attachment).to receive(:download).and_yield("fake gif data")
        allow(File).to receive(:open).with("/tmp/input.gif", "wb").and_yield(StringIO.new)
        allow(File).to receive(:open).with("/tmp/output.gif", "rb").and_return(StringIO.new)
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(1024)

        # Первые 2: get_dimensions, затем validate_output с невалидными размерами
        magick_calls = 0
        allow(MiniMagick::Image).to receive(:open) do
          magick_calls += 1
          magick_calls <= 2 ? mini_magick_before : mini_magick_invalid
        end
      end

      it "raises an error for non-512x512 output" do
        service = described_class.new(attachment)
        allow(service).to receive(:system).and_return(true)

        expect { service.process_and_replace }.to raise_error(RuntimeError, /Output dimensions invalid/)
      end
    end

    context "when record fails to save" do
      let(:input_tempfile) { instance_double(Tempfile, path: "/tmp/input.gif", close!: true) }
      let(:output_tempfile) { instance_double(Tempfile, path: "/tmp/output.gif", close!: true) }
      let(:mini_magick_before) { instance_double(MiniMagick::Image, width: 800, height: 600, destroy!: true) }
      let(:mini_magick_after) { instance_double(MiniMagick::Image, width: 512, height: 512, destroy!: true) }
      let(:errors_double) { instance_double(ActiveModel::Errors, full_messages: ["File is invalid"]) }

      before do
        tempfile_calls = 0
        allow(Tempfile).to receive(:new) do
          tempfile_calls += 1
          tempfile_calls.odd? ? input_tempfile : output_tempfile
        end

        allow(attachment).to receive(:download).and_yield("fake gif data")
        allow(File).to receive(:open).with("/tmp/input.gif", "wb").and_yield(StringIO.new)
        allow(File).to receive(:open).with("/tmp/output.gif", "rb").and_return(StringIO.new)
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(1024)

        magick_calls = 0
        allow(MiniMagick::Image).to receive(:open) do
          magick_calls += 1
          magick_calls <= 2 ? mini_magick_before : mini_magick_after
        end

        allow(record).to receive(:save).and_return(false)
        allow(record).to receive(:errors).and_return(errors_double)
      end

      it "rolls back the transaction when save fails" do
        service = described_class.new(attachment)
        allow(service).to receive(:system).and_return(true)

        # Сервис выбрасывает ActiveRecord::Rollback внутри транзакции.
        # Заглушка ловит его. Затем file.attached? (true).
        # Метод завершается без ошибки.
        service.process_and_replace

        expect(record).to have_received(:save)
        expect(attachment).to have_received(:purge)
      end
    end
  end
end
