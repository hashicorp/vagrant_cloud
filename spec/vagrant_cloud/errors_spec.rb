require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe ClientError do
    let(:subject) { described_class.new(message, body, code) }
    let(:message) { 'default error' }
    let(:body) { '' }
    let(:code) { 0 }

    describe '#initialize' do
      it 'is a StandardError' do
        expect(subject).to be_a_kind_of(StandardError)
      end

      context 'with message' do
        let(:message) { 'custom message' }

        it 'should set the message' do
          expect(subject.message).to eq(message)
        end

        it 'should output custom message with #to_s' do
          expect(subject.to_s).to eq(message)
        end
      end

      context 'with http body' do
        context 'with invalid JSON' do
          let(:body) { '{"errors:["invalid"]}' }

          it 'should not generate a parse error' do
            expect { subject }.not_to raise_error
          end

          it 'should set parse error within #error_arr' do
            expect(subject.error_arr.downcase).to include('unexpected token')
          end
        end

        context 'with valid JSON array' do
          let(:body) { '[]' }

          it 'should not generate an error' do
            expect { subject }.not_to raise_error
          end
        end

        context 'with valid JSON hash' do
          let(:body) { '{}' }

          it 'should not generate an error' do
            expect { subject }.not_to raise_error
          end
        end

        context 'with array of errors in JSON hash' do
          let(:body) { '{"errors":["error1", "error2"]}' }

          it 'should append errors to exception message' do
            expect(subject.message).to include('error1, error2')
          end

          it 'should return error with #error_arr' do
            expect(subject.error_arr).to eq(['error1', 'error2'])
          end
        end

        context 'with string errors in JSON hash' do
          let(:body) { '{"errors":"error1"}' }

          it 'should append error to exception message' do
            expect(subject.message).to include('error1')
            expect(subject.message).not_to include(',')
          end

          it 'should return error with #error_arr' do
            expect(subject.error_arr).to eq('error1')
          end
        end

        context 'with empty errors in JSON hash' do
          let(:body) { '{"errors":""}' }

          it 'should not modify the exception message' do
            expect(subject.message).to eq(message)
          end
        end

        context 'with null errors in JSON hash' do
          let(:body) { '{"errors":null}' }

          it 'should not modify the exception message' do
            expect(subject.message).to eq(message)
          end
        end
      end

      context 'with http code' do
        let(:code) { 404 }

        it 'should return the code value' do
          expect(subject.error_code).to eq(code)
        end

        it 'should be an integer' do
          expect(subject.error_code).to be_a(Integer)
        end

        context 'with string type code' do
          let(:code) { '404' }

          it 'should return the integer value' do
            expect(subject.error_code).to eq(404)
          end

          it 'should be an integer' do
            expect(subject.error_code).to be_a(Integer)
          end
        end
      end
    end
  end
end
