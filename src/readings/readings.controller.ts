import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ReadingsService } from './readings.service';
import { CreateReadingDto } from './dto/create-reading.dto';

@Controller('tempmesh')
export class ReadingsController {
  constructor(private readonly readingsService: ReadingsService) {}

  // (temporário) POST => /tempmesh/data
  @Post('data')
  @HttpCode(HttpStatus.CREATED) // HTTP 201 se conseguiu criar
  async createReadings(@Body() createReadingDto: CreateReadingDto) {
    const result = await this.readingsService.createSensorReadings(
      createReadingDto.data,
    );
    return {
      message: `${result.createdCount} registros criados com sucesso.`,
      ...result,
    };
  }
}